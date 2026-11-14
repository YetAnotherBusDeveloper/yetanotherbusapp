package tw.avianjay.taiwanbus.flutter

import kotlin.math.abs

/**
 * One user position fix. Deliberately free of android.location types so the
 * detection logic can be replayed against recorded feeds in plain JVM tests.
 */
internal data class RideGeoPoint(
    val latitude: Double,
    val longitude: Double,
    val timestampMs: Long,
    val accuracyMeters: Float = 0f,
    /** Doppler speed from the GPS chip, when the fix has one. */
    val speedMetersPerSecond: Float? = null,
)

/**
 * One vehicle position from `/realtime/buses`.
 *
 * [gpsTimeMs] is the vehicle's own clock and is what gets compared against the
 * user's track. It reaches the app 20-40 s late at the median and up to ~200 s
 * late in the tail, so "is this vehicle still reporting" is judged by
 * [receivedAtMs] instead.
 */
internal data class RideBusReport(
    val vehicleId: String,
    val pathId: Int?,
    val latitude: Double,
    val longitude: Double,
    val gpsTimeMs: Long,
    val receivedAtMs: Long,
)

internal enum class BoardingEvidence {
    NONE,

    /** The user covered the same stretch of route as a live vehicle, at the same time. */
    BUS_CO_MOVEMENT,

    /** The user's own track left the boarding stop along the route at vehicle pace. */
    SELF_PROGRESS,

    /** The user tapped "我已上車". */
    USER_CONFIRMED,
}

internal data class RideSnapshot(
    val hasBoarded: Boolean = false,
    val evidence: BoardingEvidence = BoardingEvidence.NONE,
    val trackedVehicleId: String? = null,
    val hasUsableLocation: Boolean = false,
    val boardingStopIndex: Int = -1,
    val boardingStopDistanceMeters: Double? = null,
    /** Last stop reached by the rider (their own fix, else the tracked vehicle); -1 when unknown. */
    val progressStopIndex: Int = -1,
    val nextBusVehicleId: String? = null,
    val busStopsUntilBoarding: Int? = null,
    /** Identifies the pending "did you get on?" question; 0 when there is none. */
    val boardingCheckId: Long = 0L,
    val boardingPromptDue: Boolean = false,
    val remainingStops: Int? = null,
    val passedDestinationByStops: Int? = null,
    val destinationDistanceMeters: Double? = null,
    /** Validity of the same fresh phone/bus sample that supplied the progress. */
    val hasRouteValidProgress: Boolean = false,
)

/**
 * Decides whether the user is riding the monitored route.
 *
 * Three layers, strongest evidence first:
 *
 * A. **Co-movement.** For every live vehicle, look up where the user was at the
 *    instants that vehicle reported its position. Riding together keeps the gap
 *    between the two roughly constant while both advance. This needs no plate
 *    in the ETA feed (雙北 ETAs carry none; `/realtime/buses` always does).
 *
 * B. **Self progress.** The user's own track leaving the boarding stop along the
 *    route at vehicle pace. Covers a boarded vehicle with no position feed.
 *
 * C. **The user's answer.** Once a bus has left the boarding stop and nothing
 *    shows the user stayed behind, ask. Works with no location at all.
 *
 * Everything is measured in metres along the stop sequence. A 2-D proximity
 * test would be dominated by cross-track error: against the stop-chord line,
 * bus fixes sit 8-16 m off at the median but 65-295 m at p90.
 */
internal class TripRideDetector(
    stops: List<TrackingStop>,
    private val pathId: Int,
    boardingStopId: Int?,
    destinationStopId: Int?,
) {
    private val stopIds = stops.map { it.stopId }
    private val line = RideRouteLine(stops)

    private val userTrack = ArrayDeque<UserSample>()
    private val busTracks = LinkedHashMap<String, ArrayDeque<BusSample>>()
    /** Vehicles last seen short of the boarding stop, with when that report arrived. */
    private val seenBeforeBoardingStopAt = HashMap<String, Long>()

    private val explicitBoardingIndex = indexOfStop(boardingStopId)
    private var anchoredBoardingIndex = -1
    private var destinationIndex = indexOfStop(destinationStopId)

    private var userAlongHint: Double? = null
    private var boarded = false
    private var evidence = BoardingEvidence.NONE
    private var trackedVehicleId: String? = null
    private var manualConfirmationAtMs: Long? = null
    private var manualVehicleAmbiguous = false

    /**
     * Vehicles the rider has answered "not this one" about, each with the moment
     * of that answer. The answer is about one bus, not about the trip: only the
     * vehicle it named is set aside, and only for [REJECTED_VEHICLE_TTL_MS], so
     * the next bus both raises the question and gets detected as normal. See
     * [declineBoarding].
     */
    private val rejectedAt = HashMap<String, Long>()
    private var lastDeclineAtMs = 0L

    /**
     * The departure behind the last "not yet" answer: when it was registered,
     * and whether the bus it belonged to is still unknown because only the ETA
     * had reported it.
     */
    private var declinedDepartureAtMs = 0L
    private var declinedDepartureUnattributed = false

    private var etaArrivingAtMs = 0L
    private var pendingCheckSinceMs = 0L
    private var pendingCheckVehicleId: String? = null
    private var pendingCheckAnchor: UserSample? = null

    private val boardingIndex: Int
        get() {
            val index = if (explicitBoardingIndex >= 0) explicitBoardingIndex else anchoredBoardingIndex
            return if (index >= 0 && destinationIndex >= 0) index.coerceAtMost(destinationIndex) else index
        }

    /** Choosing a destination mid-ride must not disturb what is already known about the ride. */
    fun updateDestination(destinationStopId: Int?) {
        destinationIndex = indexOfStop(destinationStopId)
    }

    /** Feeds one user fix. Returns false when the fix was rejected as unusable. */
    fun onUserLocation(point: RideGeoPoint): Boolean {
        if (point.accuracyMeters > MAX_USABLE_ACCURACY_METERS) {
            return false
        }
        val previous = userTrack.lastOrNull()
        if (previous != null) {
            val elapsedSeconds = (point.timestampMs - previous.timestampMs) / 1000.0
            if (elapsedSeconds <= 0.0) {
                // The same fix delivered again, or a clock step backwards.
                return false
            }
            val stepMeters = line.metersBetween(
                previous.latitude,
                previous.longitude,
                point.latitude,
                point.longitude,
            )
            // Faster than any bus: a GPS jump, not travel. Keeping it would
            // corrupt every window that spans it.
            if (stepMeters / elapsedSeconds > MAX_PLAUSIBLE_SPEED_MPS) {
                return false
            }
        }
        val projection = line.project(point.latitude, point.longitude, userAlongHint)
        userAlongHint = projection.alongMeters
        userTrack += UserSample(
            latitude = point.latitude,
            longitude = point.longitude,
            alongMeters = projection.alongMeters,
            timestampMs = point.timestampMs,
            accuracyMeters = point.accuracyMeters,
            speedMetersPerSecond = point.speedMetersPerSecond,
        )
        while (userTrack.size > MAX_USER_SAMPLES) {
            userTrack.removeFirst()
        }
        return true
    }

    fun onBusReports(reports: List<RideBusReport>) {
        reports.forEach { report ->
            if (report.vehicleId.isBlank() || report.gpsTimeMs <= 0L) {
                return@forEach
            }
            val track = busTracks.getOrPut(report.vehicleId) { ArrayDeque() }
            val last = track.lastOrNull()
            // Vehicles report every ~20 s but the feed is polled more often, so
            // most polls repeat the previous fix.
            if (last != null && report.gpsTimeMs <= last.gpsTimeMs) {
                return@forEach
            }
            val projection = line.project(report.latitude, report.longitude, last?.alongMeters)
            track += BusSample(
                latitude = report.latitude,
                longitude = report.longitude,
                alongMeters = projection.alongMeters,
                gpsTimeMs = report.gpsTimeMs,
                receivedAtMs = report.receivedAtMs,
                samePath = report.pathId == null || report.pathId == pathId,
                // Parked and deadheading vehicles project onto the route from
                // far away; only vehicles actually on it may announce arrivals.
                onRoute = projection.crossTrackMeters <= maxOf(
                    ON_ROUTE_MIN_CROSS_TRACK_METERS,
                    ON_ROUTE_SEGMENT_SHARE * line.segmentLengthMeters(projection.segmentIndex),
                ),
            )
            while (track.size > MAX_BUS_SAMPLES) {
                track.removeFirst()
            }
        }
    }

    /**
     * Feeds the boarding stop's ETA. An estimate that reaches zero and then
     * rolls over to the next bus means a vehicle has left, which is the only
     * departure signal available when that vehicle has no position feed.
     */
    fun onBoardingStopEta(etaSeconds: Int?, arriving: Boolean, nowMs: Long) {
        if (arriving || (etaSeconds != null && etaSeconds <= ETA_ARRIVING_SECONDS)) {
            etaArrivingAtMs = nowMs
            return
        }
        // Once the estimate reaches zero it either jumps to the next bus or
        // disappears entirely; both mean the vehicle that was arriving has gone.
        val rolledOver = etaArrivingAtMs != 0L &&
            nowMs - etaArrivingAtMs <= ETA_ROLLOVER_WINDOW_MS &&
            (etaSeconds == null || etaSeconds >= ETA_ROLLOVER_SECONDS)
        if (rolledOver) {
            etaArrivingAtMs = 0L
            registerDeparture(vehicleId = null, nowMs = nowMs)
        }
    }

    fun confirmBoardedByUser(nowMs: Long) {
        val identifiedVehicle = trackedVehicleId.takeIf { boarded }
        // A question that names a bus is about that bus: it was watched coming
        // up to the stop and leaving it, and "yes" is the rider's answer to
        // exactly that. Nothing seen afterwards can be tied to the ride as
        // firmly, however near the stop it is.
        val askedAbout = pendingCheckVehicleId.takeIf {
            pendingCheckSinceMs != 0L && nowMs - pendingCheckSinceMs in 0L..BOARDING_CHECK_MAX_AGE_MS
        }
        if (!boarded || evidence != BoardingEvidence.USER_CONFIRMED) {
            manualConfirmationAtMs = nowMs
            manualVehicleAmbiguous = false
        }
        boarded = true
        evidence = BoardingEvidence.USER_CONFIRMED
        rejectedAt.clear()
        // Confirming the ride does not confirm a plate. An already identified
        // vehicle remains the ride even if another bus is nearer the stop now.
        trackedVehicleId = identifiedVehicle ?: askedAbout ?: identifyBoardingVehicle(nowMs)
        clearPendingCheck()
    }

    /**
     * Takes up a ride the rider confirmed earlier, on a detector built since.
     *
     * The confirmation was given some way back along the route, so nothing at
     * the boarding stop now has anything to do with it: the vehicle stays
     * unknown until the rider's own position picks it out.
     */
    fun resumeConfirmedRide() {
        boarded = true
        evidence = BoardingEvidence.USER_CONFIRMED
        trackedVehicleId = null
        manualConfirmationAtMs = null
        manualVehicleAmbiguous = false
        clearPendingCheck()
    }

    /**
     * The user says they are not on the bus the app thinks they are on.
     *
     * The answer is about one bus, not about the trip, so only what was just
     * asserted is set aside: the vehicle of the pending question if there is
     * one, else the vehicle the detected ride named, for
     * [REJECTED_VEHICLE_TTL_MS]; and the rider's own movement up to this
     * moment, which no longer counts as evidence of a ride. The next bus raises
     * its own question and is detected exactly as this one was.
     *
     * Switching detection off for the rest of the trip instead would leave the
     * rider sitting on their real bus with no boarding alert and no destination
     * reminders, so one repeated question is the better failure.
     */
    fun declineBoarding(nowMs: Long) {
        val answeredAQuestion = pendingCheckSinceMs != 0L
        val rejected = pendingCheckVehicleId ?: trackedVehicleId
        boarded = false
        evidence = BoardingEvidence.NONE
        trackedVehicleId = null
        manualConfirmationAtMs = null
        manualVehicleAmbiguous = false
        lastDeclineAtMs = nowMs
        declinedDepartureAtMs = if (answeredAQuestion) pendingCheckSinceMs else nowMs
        declinedDepartureUnattributed = answeredAQuestion && rejected == null
        if (rejected != null) {
            rejectedAt[rejected] = nowMs
        }
        clearPendingCheck()
    }

    /**
     * Whether [vehicleId] is a bus the rider has already turned down and whose
     * rejection is still in force. Entries lapse after
     * [REJECTED_VEHICLE_TTL_MS] so a vehicle that comes round again is treated
     * as new.
     */
    private fun isRejected(vehicleId: String, nowMs: Long): Boolean {
        val declinedAt = rejectedAt[vehicleId] ?: return false
        return nowMs - declinedAt <= REJECTED_VEHICLE_TTL_MS
    }

    fun snapshot(nowMs: Long): RideSnapshot {
        prune(nowMs)
        val latestUser = userTrack.lastOrNull()
        val usableUser = latestUser?.takeIf { nowMs - it.timestampMs <= LOCATION_STALE_MS }
        if (anchoredBoardingIndex < 0 && usableUser != null) {
            // Used only when no boarding stop was chosen: the trip starts
            // wherever the user actually is. Only a current fix can say that —
            // a cached one from minutes ago would pin the whole trip to a stop
            // the user may have left long before.
            anchoredBoardingIndex = line.nearestStopIndex(usableUser.alongMeters)
        }
        val boardingStop = boardingIndex
        val boardingAlong = if (boardingStop >= 0) line.alongOfStop(boardingStop) else null
        val vehicles = liveVehicles(nowMs)

        if (boardingAlong != null) {
            trackDepartures(vehicles, boardingAlong, nowMs)
        }
        if (!boarded) {
            val coMovingVehicleId = detectCoMovement(nowMs)
            if (coMovingVehicleId != null) {
                markBoarded(BoardingEvidence.BUS_CO_MOVEMENT, coMovingVehicleId)
            } else if (boardingAlong != null && usableUser != null &&
                detectSelfProgress(nowMs, boardingAlong, usableUser)
            ) {
                markBoarded(BoardingEvidence.SELF_PROGRESS, vehicleId = null)
            }
        }
        trackedVehicleId = resolveTrackedVehicle(vehicles, usableUser, nowMs)
        val trackedVehicle = vehicles.firstOrNull {
            it.vehicleId == trackedVehicleId && it.samePath && it.onRoute
        }

        val nextBus = if (boardingAlong == null) {
            null
        } else {
            vehicles
                .filter { it.samePath && it.onRoute && it.alongMeters <= boardingAlong + AT_STOP_MARGIN_METERS }
                .maxByOrNull { it.alongMeters }
        }

        val progressAlong = usableUser?.alongMeters
            ?: trackedVehicle?.alongMeters?.takeIf { boarded }
        val progressStopIndex = progressAlong?.let(line::stopIndexAt) ?: -1
        val destinationStop = destinationIndex
        val stopsToGo = if (destinationStop >= 0 && progressStopIndex >= 0) {
            destinationStop - progressStopIndex
        } else {
            null
        }
        val destinationDistanceMeters = when {
            destinationStop < 0 -> null
            usableUser != null -> line.metersToStop(usableUser.latitude, usableUser.longitude, destinationStop)
            progressAlong != null -> abs(line.alongOfStop(destinationStop) - progressAlong)
            else -> null
        }
        // Resolved before the snapshot is assembled: it may retire the pending
        // question, and the id reported alongside must agree with it.
        val boardingPromptDue = resolveBoardingPromptDue(nowMs, usableUser, boardingStop)

        return RideSnapshot(
            hasBoarded = boarded,
            evidence = evidence,
            trackedVehicleId = trackedVehicleId,
            hasUsableLocation = usableUser != null,
            boardingStopIndex = boardingStop,
            boardingStopDistanceMeters = if (usableUser != null && boardingStop >= 0) {
                line.metersToStop(usableUser.latitude, usableUser.longitude, boardingStop)
            } else {
                null
            },
            progressStopIndex = progressStopIndex,
            nextBusVehicleId = nextBus?.vehicleId,
            busStopsUntilBoarding = nextBus?.let {
                (boardingStop - line.stopIndexAt(it.alongMeters)).coerceAtLeast(0)
            },
            boardingCheckId = pendingCheckSinceMs,
            boardingPromptDue = boardingPromptDue,
            remainingStops = stopsToGo?.coerceAtLeast(0),
            passedDestinationByStops = stopsToGo?.let { -it }?.takeIf { it > 0 },
            destinationDistanceMeters = destinationDistanceMeters,
            // Keep the phone's existing near-stop guard. Without a usable phone
            // fix, the tracked bus's direction and route geometry are the guard;
            // an unrelated cached phone location must not veto its progress.
            hasRouteValidProgress = when {
                usableUser != null -> line.metersToStop(
                    usableUser.latitude, usableUser.longitude, line.nearestStopIndex(usableUser.alongMeters),
                ) <= USER_STOP_PROXIMITY_MAX_METERS
                trackedVehicle != null -> trackedVehicle.samePath && trackedVehicle.onRoute
                else -> false
            },
        )
    }

    private fun markBoarded(evidence: BoardingEvidence, vehicleId: String?) {
        boarded = true
        this.evidence = evidence
        trackedVehicleId = vehicleId
        manualConfirmationAtMs = null
        manualVehicleAmbiguous = false
        clearPendingCheck()
    }

    /**
     * Layer A. The gap between the user and a vehicle is sampled at each of the
     * vehicle's reports, newest first, and must stay within
     * [COMOVE_MAX_GAP_DRIFT_METERS] over a stretch in which both really moved.
     *
     * Standing at the stop while the bus drives off makes the gap grow by the
     * bus's whole travel, and walking beside a bus stuck in traffic fails the
     * speed floor, so neither counts.
     *
     * Only an unbroken run of reports made on this trip's direction, on the
     * route, is evidence. The feed lists every vehicle of the route — the other
     * direction's, and ones parked or deadheading beside it — and each of those
     * still projects to some position along this line.
     */
    private fun detectCoMovement(nowMs: Long): String? {
        if (userTrack.size < 2) {
            return null
        }
        val pairs = ArrayList<CoMovementPair>()
        busTracks.forEach { (vehicleId, track) ->
            if (isRejected(vehicleId, nowMs)) {
                return@forEach
            }
            pairs.clear()
            track.forEach { report ->
                if (!report.samePath || !report.onRoute) {
                    // Whatever came before is not joined to what follows as
                    // though the bus had run on through.
                    pairs.clear()
                    return@forEach
                }
                if (report.receivedAtMs < nowMs - COMOVE_WINDOW_MS) {
                    return@forEach
                }
                val userAlong = userAlongAt(report.gpsTimeMs) ?: return@forEach
                pairs += CoMovementPair(userAlong, report.alongMeters, report.gpsTimeMs)
            }
            if (isCoMovement(pairs)) {
                return vehicleId
            }
        }
        return null
    }

    private fun isCoMovement(pairs: List<CoMovementPair>): Boolean {
        val newest = pairs.lastOrNull() ?: return false
        var minGap = Double.MAX_VALUE
        var maxGap = -Double.MAX_VALUE
        for (start in pairs.indices.reversed()) {
            val oldest = pairs[start]
            val gap = oldest.userAlongMeters - oldest.busAlongMeters
            minGap = minOf(minGap, gap)
            maxGap = maxOf(maxGap, gap)
            if (maxGap - minGap > COMOVE_MAX_GAP_DRIFT_METERS) {
                // Reaching further back can only widen the drift.
                return false
            }
            if (pairs.size - start < COMOVE_MIN_REPORTS) {
                continue
            }
            val spanSeconds = (newest.gpsTimeMs - oldest.gpsTimeMs) / 1000.0
            if (spanSeconds < COMOVE_MIN_SPAN_SECONDS) {
                continue
            }
            val busTravel = newest.busAlongMeters - oldest.busAlongMeters
            val userTravel = newest.userAlongMeters - oldest.userAlongMeters
            if (busTravel < COMOVE_MIN_TRAVEL_METERS ||
                userTravel < busTravel * COMOVE_MIN_USER_TRAVEL_SHARE ||
                userTravel / spanSeconds < COMOVE_MIN_USER_SPEED_MPS
            ) {
                continue
            }
            // A fixed offset between the two clocks shows up as a fixed number
            // of metres at a given speed, so the allowance grows with speed.
            val gapLimit = COMOVE_MAX_GAP_METERS +
                COMOVE_CLOCK_ALLOWANCE_SECONDS * (busTravel / spanSeconds)
            if (maxGap > gapLimit || minGap < -gapLimit) {
                continue
            }
            if (!movedAtVehicleSpeed(oldest.gpsTimeMs, newest.gpsTimeMs)) {
                continue
            }
            return true
        }
        return false
    }

    /**
     * Layer B. 500 m in 200 s is 2.5 m/s — above a brisk walk and above a bus
     * that sat in traffic for the whole window — so a pedestrian following the
     * same street from the stop is not mistaken for a passenger.
     *
     * Travel that happened before the rider last answered "not yet" does not
     * count: that is the movement the answer was about, and letting it count
     * again would overrule the answer a moment after it was given. Evidence
     * starts accumulating from scratch instead.
     */
    private fun detectSelfProgress(
        nowMs: Long,
        boardingAlong: Double,
        latestUser: UserSample,
    ): Boolean {
        if (latestUser.timestampMs < lastDeclineAtMs) {
            return false
        }
        val windowStartMs = maxOf(nowMs - SELF_PROGRESS_WINDOW_MS, lastDeclineAtMs)
        val origin = userTrack.firstOrNull { sample ->
            sample.timestampMs >= windowStartMs &&
                sample.accuracyMeters <= SELF_PROGRESS_MAX_ACCURACY_METERS &&
                abs(sample.alongMeters - boardingAlong) <= BOARDING_ORIGIN_RADIUS_METERS
        } ?: return false
        val travel = latestUser.alongMeters - origin.alongMeters
        val elapsedSeconds = (latestUser.timestampMs - origin.timestampMs) / 1000.0
        if (travel < SELF_PROGRESS_MIN_METERS || elapsedSeconds <= 0.0) {
            return false
        }
        return travel / elapsedSeconds >= SELF_PROGRESS_MIN_SPEED_MPS &&
            movedAtVehicleSpeed(origin.timestampMs, latestUser.timestampMs)
    }

    /**
     * Doppler speed is immune to the position wander that makes a stationary
     * phone look like it travelled, so when the fixes carry it, real movement
     * must show up there too.
     */
    private fun movedAtVehicleSpeed(fromMs: Long, toMs: Long): Boolean {
        var withSpeed = 0
        var fast = 0
        userTrack.forEach { sample ->
            if (sample.timestampMs < fromMs || sample.timestampMs > toMs) {
                return@forEach
            }
            val speed = sample.speedMetersPerSecond ?: return@forEach
            withSpeed++
            if (speed >= VEHICLE_SPEED_MPS) {
                fast++
            }
        }
        return withSpeed < MIN_SPEED_SAMPLES || fast >= MIN_FAST_SAMPLES
    }

    private fun trackDepartures(
        vehicles: List<LiveVehicle>,
        boardingAlong: Double,
        nowMs: Long,
    ) {
        vehicles.forEach { vehicle ->
            if (!vehicle.samePath || !vehicle.onRoute) {
                return@forEach
            }
            val offset = vehicle.alongMeters - boardingAlong
            if (offset <= AT_STOP_MARGIN_METERS) {
                seenBeforeBoardingStopAt[vehicle.vehicleId] = vehicle.receivedAtMs
            } else if (offset > LEFT_STOP_MARGIN_METERS) {
                val seenAt = seenBeforeBoardingStopAt.remove(vehicle.vehicleId) ?: return@forEach
                // A vehicle that went quiet short of the stop and turns up past
                // it much later left long ago; nobody is boarding it now.
                if (vehicle.receivedAtMs - seenAt <= DEPARTURE_MAX_REPORT_GAP_MS) {
                    registerDeparture(vehicle.vehicleId, nowMs)
                }
            }
        }
    }

    private fun registerDeparture(vehicleId: String?, nowMs: Long) {
        if (boarded) {
            return
        }
        if (vehicleId != null && isRejected(vehicleId, nowMs)) {
            // The rider already said this bus was not theirs. Asking again
            // about the same one is the noise the rejection exists to avoid;
            // every other vehicle is untouched.
            return
        }
        if (declinedDepartureAtMs != 0L && nowMs - declinedDepartureAtMs < DEPARTURE_DEDUPE_MS) {
            // One departure reaches the app twice — from the position feed and
            // from the ETA rolling over — up to a minute and a half apart, and
            // this one has already been answered. The window runs from the
            // departure, not from the answer: a rider may take minutes to
            // reply, and what leaves the stop after that is the next bus.
            if (vehicleId == null) {
                return
            }
            if (declinedDepartureUnattributed) {
                // The question came from the ETA alone, so the answer had no
                // vehicle to be held against. This is that bus, now named.
                declinedDepartureUnattributed = false
                rejectedAt[vehicleId] = lastDeclineAtMs
                return
            }
            // A different vehicle this close behind is a second bus, and gets
            // a question of its own.
        }
        if (pendingCheckSinceMs != 0L && nowMs - pendingCheckSinceMs < DEPARTURE_DEDUPE_MS) {
            // The position feed and the ETA rollover both report the same bus.
            pendingCheckVehicleId = pendingCheckVehicleId ?: vehicleId
            return
        }
        val boardingStop = boardingIndex
        val recentUser = userTrack.filter { nowMs - it.timestampMs <= DEPARTURE_USER_LOOKBACK_MS }
        // With no fix at all there is no telling where the user is, and asking
        // is the only tool left.
        val userWasAtStop = recentUser.isEmpty() || recentUser.any { sample ->
            boardingStop >= 0 &&
                line.metersToStop(sample.latitude, sample.longitude, boardingStop) <=
                BOARDING_STOP_RADIUS_METERS
        }
        if (!userWasAtStop) {
            return
        }
        pendingCheckSinceMs = nowMs
        pendingCheckVehicleId = vehicleId
        pendingCheckAnchor = recentUser.lastOrNull()
    }

    private fun resolveBoardingPromptDue(
        nowMs: Long,
        usableUser: UserSample?,
        boardingStop: Int,
    ): Boolean {
        if (boarded || pendingCheckSinceMs == 0L) {
            return false
        }
        val ageMs = nowMs - pendingCheckSinceMs
        if (ageMs > BOARDING_CHECK_MAX_AGE_MS) {
            clearPendingCheck()
            return false
        }
        if (boardingStop >= 0 && usableUser != null &&
            line.metersToStop(usableUser.latitude, usableUser.longitude, boardingStop) >
            BOARDING_STOP_ABANDONED_RADIUS_METERS
        ) {
            // The user is nowhere near the stop any more, so this bus was never
            // their ride; stop waiting for an answer.
            clearPendingCheck()
            return false
        }
        if (ageMs < BOARDING_PROMPT_DELAY_MS) {
            return false
        }
        // A stationary phone is the one thing that reliably means "still
        // waiting", so while the user has not moved there is nothing to ask.
        return !stayedBehind(nowMs, usableUser)
    }

    private fun stayedBehind(nowMs: Long, user: UserSample?): Boolean {
        user ?: return false
        if (nowMs - user.timestampMs > STAYED_BEHIND_MAX_FIX_AGE_MS ||
            user.accuracyMeters > STAYED_BEHIND_MAX_ACCURACY_METERS
        ) {
            return false
        }
        val anchor = pendingCheckAnchor ?: return false
        return line.metersBetween(anchor.latitude, anchor.longitude, user.latitude, user.longitude) <
            STAYED_BEHIND_MAX_MOVE_METERS
    }

    private fun clearPendingCheck() {
        pendingCheckSinceMs = 0L
        pendingCheckVehicleId = null
        pendingCheckAnchor = null
    }

    /**
     * Once on board, the vehicle to follow is the one the user is inside. Its
     * reported position trails the user's own fix by the feed's delay, so it is
     * expected a little behind and never far ahead. It is also on this trip's
     * direction and on the route: a vehicle parked beside the route projects
     * onto it too, and can be the nearest one there is.
     */
    private fun resolveTrackedVehicle(
        vehicles: List<LiveVehicle>,
        usableUser: UserSample?,
        nowMs: Long,
    ): String? {
        if (!boarded) {
            return null
        }
        val locked = vehicles.firstOrNull { it.vehicleId == trackedVehicleId && it.samePath && it.onRoute }
        if (usableUser == null) {
            // Remember the ride through an outage or an invalid report, but
            // only a fresh, valid report supplies progress in snapshot(). A
            // manual confirmation may also precede the first vehicle response.
            return trackedVehicleId ?: if (evidence == BoardingEvidence.USER_CONFIRMED) {
                identifyBoardingVehicle(nowMs)
            } else {
                null
            }
        }
        if (locked != null &&
            usableUser.alongMeters - locked.alongMeters in -TRACK_MAX_AHEAD_METERS..TRACK_KEEP_BEHIND_METERS
        ) {
            return locked.vehicleId
        }
        return vehicles
            .filter { it.samePath && it.onRoute }
            .filter { usableUser.alongMeters - it.alongMeters in -TRACK_MAX_AHEAD_METERS..TRACK_PICK_BEHIND_METERS }
            .minByOrNull { abs(usableUser.alongMeters - it.alongMeters) }
            ?.vehicleId
    }

    /**
     * Associates a manual confirmation with a vehicle, not just a route.
     *
     * The bus must have an unbroken run on this direction and route containing
     * a fix physically at the boarding stop, and still be at most 250 m ahead.
     * Projection alone would clamp a bus before the first stop to zero
     * progress, or put a bus on a parallel street level with the stop.
     *
     * That fix must have been made in the minute and a half up to the moment
     * the rider confirmed, by the vehicle's own clock. The report carrying it
     * can reach the app afterwards — the feed runs half a minute behind — which
     * is what the two-minute window is for. A bus that pulls in after the
     * rider said they were already on one is the next bus, whenever it is seen.
     */
    private fun identifyBoardingVehicle(nowMs: Long): String? {
        val confirmedAt = manualConfirmationAtMs ?: return null
        if (nowMs - confirmedAt !in 0L..MANUAL_IDENTIFICATION_WINDOW_MS || manualVehicleAmbiguous) {
            return null
        }
        val boardingStop = boardingIndex
        val hasUsableUser = userTrack.lastOrNull()?.let { nowMs - it.timestampMs <= LOCATION_STALE_MS } == true
        if (boardingStop < 0 || hasUsableUser) {
            // With a usable location the nearest vehicle is resolved from the user.
            return null
        }
        val boardingAlong = line.alongOfStop(boardingStop)
        val candidates = liveVehicles(nowMs).filter { vehicle ->
            if (!vehicle.samePath || !vehicle.onRoute ||
                vehicle.alongMeters - boardingAlong !in -AT_STOP_MARGIN_METERS..MANUAL_VEHICLE_MAX_AHEAD_METERS
            ) {
                return@filter false
            }
            val track = busTracks[vehicle.vehicleId] ?: return@filter false
            val latest = track.lastOrNull() ?: return@filter false
            if (nowMs - latest.receivedAtMs !in 0L..MANUAL_VEHICLE_EVIDENCE_MAX_AGE_MS) {
                return@filter false
            }
            track.reversed().takeWhile { it.samePath && it.onRoute }.any { sample ->
                confirmedAt - sample.gpsTimeMs in 0L..MANUAL_VEHICLE_EVIDENCE_MAX_AGE_MS &&
                    abs(sample.alongMeters - boardingAlong) <= AT_STOP_MARGIN_METERS &&
                    line.metersToStop(sample.latitude, sample.longitude, boardingStop) <=
                    MANUAL_AT_STOP_RADIUS_METERS
            }
        }
        if (candidates.size > 1) {
            // One candidate later leaving the distance bound does not prove
            // that the rider took the other one. A usable phone fix can still
            // identify the ride through resolveTrackedVehicle().
            manualVehicleAmbiguous = true
        }
        return candidates.singleOrNull()?.vehicleId
    }

    private fun liveVehicles(nowMs: Long): List<LiveVehicle> {
        return busTracks.entries.mapNotNull { (vehicleId, track) ->
            val last = track.lastOrNull() ?: return@mapNotNull null
            if (nowMs - last.receivedAtMs > BUS_REPORT_STALE_MS) {
                return@mapNotNull null
            }
            LiveVehicle(vehicleId, last.alongMeters, last.samePath, last.onRoute, last.receivedAtMs)
        }
    }

    /** The user's along-route position at [timestampMs], linearly interpolated. */
    private fun userAlongAt(timestampMs: Long): Double? {
        var previous: UserSample? = null
        userTrack.forEach { sample ->
            if (sample.timestampMs >= timestampMs) {
                val before = previous
                if (before == null) {
                    return sample.alongMeters.takeIf {
                        sample.timestampMs - timestampMs <= INTERPOLATION_TOLERANCE_MS
                    }
                }
                val spanMs = sample.timestampMs - before.timestampMs
                if (spanMs > MAX_INTERPOLATION_SPAN_MS) {
                    // No fixes for too long to guess where the user was.
                    return null
                }
                val fraction = (timestampMs - before.timestampMs).toDouble() / spanMs
                return before.alongMeters + fraction * (sample.alongMeters - before.alongMeters)
            }
            previous = sample
        }
        return previous?.alongMeters?.takeIf {
            timestampMs - (previous?.timestampMs ?: 0L) <= INTERPOLATION_TOLERANCE_MS
        }
    }

    private fun prune(nowMs: Long) {
        while (userTrack.isNotEmpty() && nowMs - userTrack.first().timestampMs > USER_TRACK_MAX_AGE_MS) {
            userTrack.removeFirst()
        }
        busTracks.values.forEach { track ->
            while (track.isNotEmpty() && nowMs - track.first().receivedAtMs > BUS_TRACK_MAX_AGE_MS) {
                track.removeFirst()
            }
        }
        busTracks.entries.removeAll { it.value.isEmpty() }
        rejectedAt.entries.removeAll { nowMs - it.value > REJECTED_VEHICLE_TTL_MS }
        seenBeforeBoardingStopAt.keys.retainAll(busTracks.keys)
    }

    private fun indexOfStop(stopId: Int?): Int {
        return if (stopId == null) -1 else stopIds.indexOf(stopId)
    }

    private data class UserSample(
        val latitude: Double,
        val longitude: Double,
        val alongMeters: Double,
        val timestampMs: Long,
        val accuracyMeters: Float,
        val speedMetersPerSecond: Float?,
    )

    private data class BusSample(
        val latitude: Double,
        val longitude: Double,
        val alongMeters: Double,
        val gpsTimeMs: Long,
        val receivedAtMs: Long,
        val samePath: Boolean,
        val onRoute: Boolean,
    )

    private data class LiveVehicle(
        val vehicleId: String,
        val alongMeters: Double,
        val samePath: Boolean,
        val onRoute: Boolean,
        val receivedAtMs: Long,
    )

    private data class CoMovementPair(
        val userAlongMeters: Double,
        val busAlongMeters: Double,
        val gpsTimeMs: Long,
    )

    private companion object {
        const val MAX_USER_SAMPLES = 240
        const val MAX_BUS_SAMPLES = 60
        const val USER_TRACK_MAX_AGE_MS = 400_000L
        const val BUS_TRACK_MAX_AGE_MS = 360_000L

        const val MAX_USABLE_ACCURACY_METERS = 100f
        const val LOCATION_STALE_MS = 90_000L
        const val USER_STOP_PROXIMITY_MAX_METERS = 100.0
        const val MAX_PLAUSIBLE_SPEED_MPS = 55.0
        const val INTERPOLATION_TOLERANCE_MS = 6_000L
        const val MAX_INTERPOLATION_SPAN_MS = 30_000L

        const val COMOVE_WINDOW_MS = 180_000L
        const val COMOVE_MIN_REPORTS = 3
        const val COMOVE_MIN_SPAN_SECONDS = 30.0
        const val COMOVE_MIN_TRAVEL_METERS = 150.0
        const val COMOVE_MIN_USER_TRAVEL_SHARE = 0.7
        const val COMOVE_MIN_USER_SPEED_MPS = 2.2
        const val COMOVE_MAX_GAP_DRIFT_METERS = 110.0
        const val COMOVE_MAX_GAP_METERS = 200.0
        const val COMOVE_CLOCK_ALLOWANCE_SECONDS = 12.0

        const val SELF_PROGRESS_WINDOW_MS = 200_000L
        const val SELF_PROGRESS_MIN_METERS = 500.0
        const val SELF_PROGRESS_MIN_SPEED_MPS = 2.5
        const val SELF_PROGRESS_MAX_ACCURACY_METERS = 60f
        const val BOARDING_ORIGIN_RADIUS_METERS = 250.0

        const val VEHICLE_SPEED_MPS = 3f
        const val MIN_SPEED_SAMPLES = 3
        const val MIN_FAST_SAMPLES = 2

        const val BUS_REPORT_STALE_MS = 180_000L
        const val ON_ROUTE_MIN_CROSS_TRACK_METERS = 150.0
        const val ON_ROUTE_SEGMENT_SHARE = 0.6
        const val AT_STOP_MARGIN_METERS = 40.0
        const val LEFT_STOP_MARGIN_METERS = 120.0
        const val DEPARTURE_MAX_REPORT_GAP_MS = 180_000L
        const val MANUAL_AT_STOP_RADIUS_METERS = 80.0
        const val MANUAL_VEHICLE_MAX_AHEAD_METERS = 250.0
        const val MANUAL_VEHICLE_EVIDENCE_MAX_AGE_MS = 90_000L
        const val MANUAL_IDENTIFICATION_WINDOW_MS = 120_000L

        const val ETA_ARRIVING_SECONDS = 30
        const val ETA_ROLLOVER_SECONDS = 240
        const val ETA_ROLLOVER_WINDOW_MS = 150_000L

        const val DEPARTURE_DEDUPE_MS = 90_000L
        const val DEPARTURE_USER_LOOKBACK_MS = 150_000L
        const val BOARDING_STOP_RADIUS_METERS = 300.0
        const val BOARDING_STOP_ABANDONED_RADIUS_METERS = 400.0
        const val BOARDING_PROMPT_DELAY_MS = 40_000L
        const val BOARDING_CHECK_MAX_AGE_MS = 300_000L

        /**
         * How long a turned-down vehicle stays set aside. Long enough to cover
         * the wait for the next bus being asked about, short enough that a
         * vehicle which really is the rider's — a late arrival, or the same
         * vehicle on its next trip — is not written off for the rest of the day.
         */
        const val REJECTED_VEHICLE_TTL_MS = 1_200_000L
        const val STAYED_BEHIND_MAX_FIX_AGE_MS = 30_000L
        const val STAYED_BEHIND_MAX_ACCURACY_METERS = 50f
        const val STAYED_BEHIND_MAX_MOVE_METERS = 60.0

        const val TRACK_MAX_AHEAD_METERS = 250.0
        const val TRACK_KEEP_BEHIND_METERS = 2_500.0
        const val TRACK_PICK_BEHIND_METERS = 1_500.0
    }
}
