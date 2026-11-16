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
    /**
     * For a vehicle of another route of the family: the stops of this trip's
     * path that its own route also calls at. Null for a vehicle of the route
     * itself, which calls at all of them.
     */
    val servedStopIds: Set<Int>? = null,
)

/**
 * What the stop feed says of one bus heading for the boarding stop.
 *
 * Being listed is not being there. The backend lists a vehicle under the stop
 * it will reach next, with an estimate that can be three quarters of an hour;
 * what places it at the stop is [arriving], or its own estimate having run out.
 */
internal data class StopFeedBus(
    /** Null when the feed gives the bus no plate, as 雙北's does not. */
    val vehicleId: String?,
    /** Its own estimate for the stop; null when the feed lists it without one. */
    val etaSeconds: Int?,
    /** The feed flags it as arriving at the stop. */
    val arriving: Boolean = false,
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

    /**
     * For each vehicle, a report that put it impossibly far from where it was,
     * kept back until its next report shows which of the two places was right.
     * See [onBusReports].
     */
    private val unconfirmedLeaps = HashMap<String, BusSample>()
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
     * [declineBoarding]. A later "I have boarded" leaves these standing: it is
     * said of some other bus, and they are how that bus is told from these.
     */
    private val rejectedAt = HashMap<String, Long>()
    private var lastDeclineAtMs = 0L

    /**
     * The departures the last "not yet" answered, kept for as long as the other
     * feed may still report them; and when a detected ride was last turned down.
     */
    private val declinedDepartures = ArrayList<Departure>()
    private var declinedRideAtMs = 0L

    /** When the stop feed last had a bus at the boarding stop, or due there; 0 when none is. */
    private var etaArrivingAtMs = 0L

    /** When the stop feed last carried a live estimate: a bus arriving, or one due within four minutes. */
    private var etaLiveAtMs = 0L

    /**
     * Every named bus the stop feed has placed at the stop since one was last
     * due there, with when it was first and last placed there.
     */
    private val etaArrivingVehicles = HashMap<String, StopPresence>()

    /** Every named bus the feed has had within four minutes of the stop meanwhile. */
    private val etaNearbyVehicles = HashSet<String>()

    /** Whether the feed has, meanwhile, had a bus at the stop without saying which. */
    private var etaArrivalUnidentified = false

    /**
     * The pending "did you get on?" question: its id, and every bus that has
     * left the boarding stop while it has stood. The question says only that a
     * bus has just left, so it is about all of them.
     */
    private var pendingCheckSinceMs = 0L
    private val pendingDepartures = ArrayList<Departure>()
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
            // A phone can be anywhere. One on another road still projects to a
            // position along this route, and moves along it as it goes.
            onRoute = isOnRoute(projection),
        )
        while (userTrack.size > MAX_USER_SAMPLES) {
            userTrack.removeFirst()
        }
        return true
    }

    /**
     * Feeds one poll of the vehicle feed.
     *
     * A vehicle that reports itself further from its last position than a bus
     * can drive in the time between is not believed at once. The recorded
     * feeds have such a report in one of every two thousand — a vehicle seven
     * kilometres away forty seconds later — and with no phone fix a single one
     * would carry the ride past the destination and sound the overshoot alarm.
     * The report is kept back instead: the vehicle counts as heard from, but
     * not as being anywhere. Its next report settles it. One that fits the
     * track shows the leap was a stray fix, and it is dropped; one that could
     * have been driven to from the kept-back position confirms that position,
     * and both join the track as a new stretch.
     */
    fun onBusReports(reports: List<RideBusReport>) {
        reports.forEach { report ->
            if (report.vehicleId.isBlank() || report.gpsTimeMs <= 0L) {
                return@forEach
            }
            val track = busTracks.getOrPut(report.vehicleId) { ArrayDeque() }
            val last = track.lastOrNull()
            val leap = unconfirmedLeaps[report.vehicleId]
            // Vehicles report every ~20 s but the feed is polled more often, so
            // most polls repeat the previous fix.
            if (report.gpsTimeMs <= (leap?.gpsTimeMs ?: last?.gpsTimeMs ?: 0L)) {
                return@forEach
            }
            if (last == null || isDrivable(last, report)) {
                unconfirmedLeaps.remove(report.vehicleId)
                track += sampleOf(report, hint = last?.alongMeters)
            } else if (leap != null && isDrivable(leap, report)) {
                // It went on from where the leap put it: that was the vehicle.
                unconfirmedLeaps.remove(report.vehicleId)
                track += leap.copy(startsNewStretch = true)
                track += sampleOf(report, hint = leap.alongMeters)
            } else {
                // Too far from the track, and from any leap before it.
                unconfirmedLeaps[report.vehicleId] = sampleOf(report, hint = null)
            }
            while (track.size > MAX_BUS_SAMPLES) {
                track.removeFirst()
            }
        }
    }

    private fun sampleOf(report: RideBusReport, hint: Double?): BusSample {
        val projection = line.project(report.latitude, report.longitude, hint)
        return BusSample(
            latitude = report.latitude,
            longitude = report.longitude,
            alongMeters = projection.alongMeters,
            gpsTimeMs = report.gpsTimeMs,
            receivedAtMs = report.receivedAtMs,
            samePath = report.pathId == null || report.pathId == pathId,
            // Parked and deadheading vehicles project onto the route from
            // far away; only vehicles actually on it may announce arrivals.
            onRoute = isOnRoute(projection) && runsHere(report.servedStopIds, projection.alongMeters),
        )
    }

    /**
     * Whether a vehicle whose route calls at [servedStopIds] is, at
     * [alongMeters], on a stretch its route shares with this trip's.
     *
     * A variant of the route runs along it for some of its stops and then goes
     * its own way — to another platform of the same terminal, say, seventy
     * metres from this route's. Its position still projects onto this route,
     * as near the last stop as makes no difference, and would be read as the
     * ride arriving at a stop that bus never calls at. So a variant's position
     * counts only between the first and the last stop the two routes share.
     */
    private fun runsHere(servedStopIds: Set<Int>?, alongMeters: Double): Boolean {
        servedStopIds ?: return true
        val first = stopIds.indexOfFirst { it in servedStopIds }
        val last = stopIds.indexOfLast { it in servedStopIds }
        return first >= 0 &&
            alongMeters >= line.alongOfStop(first) - AT_STOP_MARGIN_METERS &&
            alongMeters <= line.alongOfStop(last) + AT_STOP_MARGIN_METERS
    }

    /** Whether a bus at [from] could have driven to where [report] puts it by then. */
    private fun isDrivable(from: BusSample, report: RideBusReport): Boolean {
        val elapsedSeconds = (report.gpsTimeMs - from.gpsTimeMs) / 1000.0
        if (elapsedSeconds <= 0.0) {
            return false
        }
        val meters = line.metersBetween(from.latitude, from.longitude, report.latitude, report.longitude)
        return meters <= MAX_BUS_STEP_ALLOWANCE_METERS + MAX_PLAUSIBLE_BUS_SPEED_MPS * elapsedSeconds
    }

    /**
     * Whether a projected fix lies on the route, rather than merely level with
     * some point of it. Everything here is measured along the stop sequence,
     * and a fix kilometres to one side still has a position along it. The
     * allowance grows with the stretch between two stops, because the road
     * between them is not the straight line the stops are joined by.
     */
    private fun isOnRoute(projection: RideProjection): Boolean =
        projection.crossTrackMeters <= maxOf(
            ON_ROUTE_MIN_CROSS_TRACK_METERS,
            ON_ROUTE_SEGMENT_SHARE * line.segmentLengthMeters(projection.segmentIndex),
        )

    /**
     * Feeds the boarding stop's entry in the stop feed. A bus due at the stop,
     * followed by the estimate rolling over to the next bus or vanishing, means
     * a vehicle has left — the only departure signal there is when that
     * vehicle has no position feed.
     *
     * [etaSeconds] is the stop's estimate, [arriving] whether the feed says
     * outright that a bus is arriving, and [buses] what it says of each bus
     * heading for the stop.
     *
     * A bus is due when the feed flags one as arriving, or the estimate is
     * within half a minute. An estimate that has run out — the backend counts
     * it down to −1 and leaves it there — says a bus was due only as the end
     * of a countdown this detector watched: in recorded feeds every one of
     * those was a bus passing the stop, and they are most of what 雙北, whose
     * feed never flags an arrival, has to offer. By itself, with no estimate
     * before it, it is a stop nobody is counting down to, and no bus.
     *
     * Which bus left is said only when the feed leaves one possibility. It
     * must have placed exactly one named bus at the stop; none it did not
     * name; and no other named bus within four minutes of it meanwhile, since
     * a bus that close can pull in and leave between two polls. Otherwise the
     * rollover is a bus leaving, and no more than that.
     */
    fun onBoardingStopEta(
        etaSeconds: Int?,
        arriving: Boolean,
        nowMs: Long,
        buses: List<StopFeedBus> = emptyList(),
    ) {
        val ranOut = !arriving && etaSeconds != null && etaSeconds < 0
        val busDue = arriving ||
            (etaSeconds != null && etaSeconds in 0..ETA_ARRIVING_SECONDS) ||
            (ranOut && etaLiveAtMs != 0L && nowMs - etaLiveAtMs <= ETA_RAN_OUT_MAX_MS)
        if (arriving || (etaSeconds != null && etaSeconds in 0 until ETA_ROLLOVER_SECONDS)) {
            etaLiveAtMs = nowMs
        }
        val nearby = buses.filter { bus ->
            bus.vehicleId != null &&
                (bus.arriving || bus.etaSeconds == null || bus.etaSeconds < ETA_ROLLOVER_SECONDS)
        }.mapNotNull { it.vehicleId }
        val arrivalOpen = etaArrivingAtMs != 0L && nowMs - etaArrivingAtMs <= ETA_ROLLOVER_WINDOW_MS
        if (busDue) {
            if (!arrivalOpen) {
                forgetStopArrival()
            }
            etaArrivingAtMs = nowMs
            val there = buses.filter { it.arriving || (it.etaSeconds != null && it.etaSeconds <= 0) }
            there.mapNotNull { it.vehicleId }.forEach { vehicleId ->
                etaArrivingVehicles.getOrPut(vehicleId) { StopPresence(sinceMs = nowMs) }.untilMs = nowMs
            }
            etaNearbyVehicles += nearby
            // A bus there with no plate; or the feed saying one is arriving
            // and listing none that is.
            if (there.any { it.vehicleId == null } || (arriving && there.isEmpty())) {
                etaArrivalUnidentified = true
            }
            return
        }
        if (ranOut || !arrivalOpen) {
            // A stale estimate is neither a bus due nor the next bus's.
            return
        }
        if (etaSeconds == null || etaSeconds >= ETA_ROLLOVER_SECONDS) {
            // Once a bus has been due the estimate either jumps to the next
            // bus or disappears entirely; both mean that bus has gone.
            val only = etaArrivingVehicles.keys.singleOrNull()
            val departed = only?.takeUnless {
                etaArrivalUnidentified || etaNearbyVehicles.any { it != only }
            }
            forgetStopArrival()
            registerDeparture(vehicleId = departed, nowMs = nowMs, byEta = true)
        } else {
            // Between half a minute and four minutes out: this one too may
            // have come and gone by the time the estimate rolls over.
            etaNearbyVehicles += nearby
        }
    }

    private fun forgetStopArrival() {
        etaArrivingAtMs = 0L
        etaArrivingVehicles.clear()
        etaNearbyVehicles.clear()
        etaArrivalUnidentified = false
    }

    /**
     * Whether the stop feed had a named bus other than [except] at the boarding
     * stop around [atMs]. It may have no position feed to be seen by, and the
     * rider can be boarding it all the same. A poll is some seconds behind
     * the street, so a bus first placed there shortly after [atMs] counts too.
     */
    private fun theStopFeedHadAnotherBusThere(atMs: Long, except: String): Boolean =
        etaArrivingVehicles.any { (vehicleId, presence) ->
            vehicleId != except && !isRejected(vehicleId, atMs) &&
                presence.sinceMs <= atMs + STOP_FEED_LAG_MS &&
                presence.untilMs >= atMs - MANUAL_VEHICLE_EVIDENCE_MAX_AGE_MS
        }

    /**
     * The rider says they are on board.
     *
     * [answeredCheckId] is the [RideSnapshot.boardingCheckId] of the question
     * being answered, and null when nothing was asked: "I have boarded" is
     * always on offer, and a rider who uses it may never have seen a question —
     * one can be pending, about a bus that just left, before it is ever shown.
     *
     * Either way this confirms the ride, not a plate. A vehicle is named only
     * when the feeds leave one bus the rider can be on: in answer to the
     * question, the one bus that left while it stood ([busTheQuestionIsAbout]);
     * unprompted, the one bus standing at the stop ([identifyBoardingVehicle]).
     * Following the wrong bus sounds the destination reminders for a journey
     * the rider is not making, so anything less leaves the vehicle unknown
     * until the rider's own position picks it out.
     */
    fun confirmBoardedByUser(nowMs: Long, answeredCheckId: Long? = null) {
        noteDepartures(nowMs)
        val identifiedVehicle = trackedVehicleId.takeIf { boarded }
        // An answer to a question since replaced by another names nothing.
        val askedAbout = if (answeredCheckId != null && answeredCheckId == pendingCheckSinceMs) {
            busTheQuestionIsAbout(nowMs)
        } else {
            null
        }
        if (!boarded || evidence != BoardingEvidence.USER_CONFIRMED) {
            // Only unprompted is "I have boarded" read against what is standing
            // at the stop; an answer names a bus through its question or not
            // at all.
            manualConfirmationAtMs = nowMs.takeIf { answeredCheckId == null }
            // And not even unprompted while a bus that has left is still to be
            // answered for: the rider may be on that one, and has not said.
            manualVehicleAmbiguous = departuresTheQuestionCovers(nowMs).isNotEmpty()
        }
        boarded = true
        evidence = BoardingEvidence.USER_CONFIRMED
        // An already identified vehicle remains the ride even if another bus
        // is nearer the stop now.
        trackedVehicleId = identifiedVehicle ?: askedAbout ?: identifyBoardingVehicle(nowMs)
        clearPendingCheck()
    }

    /**
     * Counts the buses that have left the boarding stop according to the
     * reports received so far. What an answer means depends on that count, and
     * it must not depend on whether a snapshot happened to be taken between
     * the last report coming in and the rider answering.
     */
    private fun noteDepartures(nowMs: Long) {
        val boardingStop = boardingIndex
        if (boardingStop >= 0) {
            trackDepartures(liveVehicles(nowMs), line.alongOfStop(boardingStop), nowMs)
        }
    }

    /** The buses that have left the boarding stop while the pending question has stood. */
    private fun departuresTheQuestionCovers(nowMs: Long): List<Departure> =
        pendingDepartures.filter { nowMs - it.atMs in 0L..BOARDING_CHECK_MAX_AGE_MS }

    /**
     * The one bus a "yes" to the pending question can mean; null when that
     * cannot be told.
     *
     * The question does not name a bus — riders do not know plates — only says
     * that one has just left. So the answer names a vehicle when exactly one
     * has left while the question stood, a feed named it, no rollover of the
     * ETA is unaccounted for beside it, and no other bus is at the stop for the
     * rider to have boarded since. Two that
     * left close together, or one that left as another pulled in, leave "yes"
     * true of either.
     */
    private fun busTheQuestionIsAbout(nowMs: Long): String? {
        val departure = departuresTheQuestionCovers(nowMs).singleOrNull() ?: return null
        if (departure.mayBeTwoBuses) {
            return null
        }
        val vehicleId = departure.vehicleId ?: return null
        val boardingStop = boardingIndex
        if (boardingStop < 0 || anotherBusIsBoardable(nowMs, line.alongOfStop(boardingStop), vehicleId)) {
            return null
        }
        return vehicleId
    }

    /**
     * Takes up a ride the rider confirmed earlier, on a detector built since.
     *
     * [knownVehicleId] is the bus that ride had been identified as being on,
     * if it had: it is the same ride, so it is the same bus, and with no phone
     * fix its positions are the only measure of how far the ride has got.
     *
     * When none was identified the vehicle stays unknown until the rider's own
     * position picks it out. The confirmation was given some way back along
     * the route, so nothing at the boarding stop now has anything to do with
     * it.
     */
    fun resumeConfirmedRide(knownVehicleId: String? = null) {
        boarded = true
        evidence = BoardingEvidence.USER_CONFIRMED
        trackedVehicleId = knownVehicleId
        manualConfirmationAtMs = null
        manualVehicleAmbiguous = false
        clearPendingCheck()
    }

    /**
     * The user says they are not on the bus the app thinks they are on.
     *
     * The answer is about the buses that have gone, not about the trip, so only
     * what was just asserted is set aside: every bus that left while the
     * pending question stood — a rider still waiting is on none of them — else
     * the vehicle the detected ride named, for [REJECTED_VEHICLE_TTL_MS]; and
     * the rider's own movement up to this moment, which no longer counts as
     * evidence of a ride. The next bus raises its own question and is detected
     * exactly as these were.
     *
     * Switching detection off for the rest of the trip instead would leave the
     * rider sitting on their real bus with no boarding alert and no destination
     * reminders, so one repeated question is the better failure.
     *
     * [answeredCheckId] is the question being answered, as for
     * [confirmBoardedByUser]. "Not yet" to a question that is no longer the
     * one pending — replaced by another, or settled by a ride since detected
     * or confirmed — says nothing about the buses the new one is about, and
     * nothing about that ride: it was given before either.
     *
     * Returns whether the answer changed what is known of the ride.
     */
    fun declineBoarding(nowMs: Long, answeredCheckId: Long? = null): Boolean {
        noteDepartures(nowMs)
        if (answeredCheckId != null && answeredCheckId != pendingCheckSinceMs) {
            if (!boarded) {
                // Still true of the rider's movement so far, and of nothing else.
                lastDeclineAtMs = nowMs
            }
            return false
        }
        val askedAbout = pendingDepartures.toList()
        val rejected = if (askedAbout.isEmpty()) {
            listOfNotNull(trackedVehicleId)
        } else {
            askedAbout.mapNotNull { it.vehicleId }
        }
        boarded = false
        evidence = BoardingEvidence.NONE
        trackedVehicleId = null
        manualConfirmationAtMs = null
        manualVehicleAmbiguous = false
        lastDeclineAtMs = nowMs
        declinedDepartures.clear()
        declinedDepartures += askedAbout
        declinedRideAtMs = if (askedAbout.isEmpty()) nowMs else 0L
        rejected.forEach { rejectedAt[it] = nowMs }
        clearPendingCheck()
        return true
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
        if (anchoredBoardingIndex < 0 && usableUser != null && usableUser.onRoute) {
            // Used only when no boarding stop was chosen: the trip starts
            // wherever the user actually is. Only a current fix can say that —
            // a cached one from minutes ago would pin the whole trip to a stop
            // the user may have left long before — and only one made on the
            // route: from anywhere else it would name the stop the user
            // happens to be level with.
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
            } else if (boardingStop >= 0 && usableUser != null &&
                detectSelfProgress(nowMs, boardingStop, usableUser)
            ) {
                markBoarded(BoardingEvidence.SELF_PROGRESS, vehicleId = null)
            }
        }
        trackedVehicleId = resolveTrackedVehicle(vehicles, usableUser, nowMs)
        val trackedVehicle = vehicles.firstOrNull {
            it.vehicleId == trackedVehicleId && it.samePath && it.onRoute && !it.positionUnconfirmed
        }

        val nextBus = if (boardingAlong == null) {
            null
        } else {
            vehicles
                .filter {
                    it.samePath && it.onRoute && !it.positionUnconfirmed &&
                        it.alongMeters <= boardingAlong + AT_STOP_MARGIN_METERS
                }
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
     * still projects to some position along this line. The same goes for the
     * rider: a phone travelling a parallel road keeps level with a bus on this
     * one without being on it.
     *
     * Nor is anything from before the rider last said "not yet". That answer
     * was about what they had been doing, beside whichever bus: two buses
     * running together would otherwise have the second detected, from the
     * same minute of movement, the moment the first was turned down.
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
                if (report.startsNewStretch) {
                    // Nothing is known of how it got here from where it was.
                    pairs.clear()
                }
                if (!report.samePath || !report.onRoute) {
                    // Whatever came before is not joined to what follows as
                    // though the bus had run on through.
                    pairs.clear()
                    return@forEach
                }
                if (report.receivedAtMs < nowMs - COMOVE_WINDOW_MS || report.gpsTimeMs < lastDeclineAtMs) {
                    return@forEach
                }
                // Fixes from before the answer are not interpolated from either.
                val user = userAt(report.gpsTimeMs, notBeforeMs = lastDeclineAtMs) ?: return@forEach
                if (!user.onRoute) {
                    pairs.clear()
                    return@forEach
                }
                pairs += CoMovementPair(user.alongMeters, report.alongMeters, report.gpsTimeMs)
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
     *
     * The travel is measured along the route, so it has to be travel on the
     * route: it starts at the boarding stop itself, not at a point level with
     * it on another road, and no fix since has been off the route. And it is
     * travel the phone made. Where the route uses a street twice, a fix a
     * little way back down it can be placed on the later pass, a loop further
     * on; the ground the phone covered meanwhile shows that it was not.
     */
    private fun detectSelfProgress(
        nowMs: Long,
        boardingStop: Int,
        latestUser: UserSample,
    ): Boolean {
        if (latestUser.timestampMs < lastDeclineAtMs) {
            return false
        }
        val windowStartMs = maxOf(nowMs - SELF_PROGRESS_WINDOW_MS, lastDeclineAtMs)
        val lastOffRouteAtMs = userTrack.lastOrNull { !it.onRoute }?.timestampMs ?: Long.MIN_VALUE
        val origin = userTrack.firstOrNull { sample ->
            sample.timestampMs >= windowStartMs &&
                sample.timestampMs > lastOffRouteAtMs &&
                sample.accuracyMeters <= SELF_PROGRESS_MAX_ACCURACY_METERS &&
                line.metersToStop(sample.latitude, sample.longitude, boardingStop) <=
                BOARDING_ORIGIN_RADIUS_METERS
        } ?: return false
        val travel = latestUser.alongMeters - origin.alongMeters
        val elapsedSeconds = (latestUser.timestampMs - origin.timestampMs) / 1000.0
        if (travel < SELF_PROGRESS_MIN_METERS || elapsedSeconds <= 0.0) {
            return false
        }
        var groundMeters = 0.0
        var previous = origin
        userTrack.forEach { sample ->
            if (sample.timestampMs > origin.timestampMs) {
                groundMeters += line.metersBetween(
                    previous.latitude, previous.longitude, sample.latitude, sample.longitude,
                )
                previous = sample
            }
        }
        if (travel > groundMeters * SELF_PROGRESS_MAX_STRETCH + SELF_PROGRESS_STRETCH_ALLOWANCE_METERS) {
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
            if (!vehicle.samePath || !vehicle.onRoute || vehicle.positionUnconfirmed) {
                // Where it is cannot be said, so neither can whether it left.
                return@forEach
            }
            val offset = vehicle.alongMeters - boardingAlong
            if (offset <= AT_STOP_MARGIN_METERS) {
                seenBeforeBoardingStopAt[vehicle.vehicleId] = vehicle.receivedAtMs
            } else if (offset > LEFT_STOP_MARGIN_METERS) {
                val seenAt = seenBeforeBoardingStopAt.remove(vehicle.vehicleId) ?: return@forEach
                // A vehicle that went quiet short of the stop and turns up past
                // it much later left long ago; nobody is boarding it now. Nor
                // one that got past it by a leap no bus could have driven:
                // nobody watched that pull away from the stop.
                if (vehicle.receivedAtMs - seenAt <= DEPARTURE_MAX_REPORT_GAP_MS &&
                    !leaptSince(vehicle.vehicleId, seenAt)
                ) {
                    registerDeparture(vehicle.vehicleId, nowMs)
                }
            }
        }
    }

    /** Whether [vehicleId] has, since [sinceMs], reached a position by a leap no bus could drive. */
    private fun leaptSince(vehicleId: String, sinceMs: Long): Boolean =
        busTracks[vehicleId].orEmpty().any { it.startsNewStretch && it.receivedAtMs > sinceMs }

    /**
     * Counts a bus leaving the boarding stop, which is what the question is
     * asked about.
     *
     * One departure can reach the app twice, up to a minute and a half apart:
     * from the position feed, which names the vehicle, and from the ETA rolling
     * over, which names it only where the stop feed says which bus was at the
     * stop. Two reports naming the same vehicle are one departure, and two
     * naming different vehicles are two, however close together.
     *
     * A rollover that names nothing, beside a departure the position feed
     * reported, is not asked about twice — it is most often the same bus — but
     * nothing shows that it is. It may be a second bus with no position feed,
     * so the pair is remembered as possibly two ([Departure.mayBeTwoBuses])
     * and an answer does not name the one that happens to have a plate.
     */
    private fun registerDeparture(vehicleId: String?, nowMs: Long, byEta: Boolean = false) {
        if (boarded) {
            return
        }
        if (vehicleId != null && isRejected(vehicleId, nowMs)) {
            // The rider already said this bus was not theirs. Asking again
            // about the same one is the noise the rejection exists to avoid;
            // every other vehicle is untouched.
            if (byEta) {
                declinedDepartures.firstOrNull { it.vehicleId == vehicleId }?.reportedByEta = true
            }
            return
        }
        if (answeredByTheLastDecline(vehicleId, nowMs, byEta)) {
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
        if (pendingCheckSinceMs != 0L) {
            if (coveredByThePendingQuestion(vehicleId, nowMs, byEta)) {
                return
            }
            // Another bus has left with the question unanswered. It joins what
            // the question is about rather than taking it over: the rider may
            // be on either, and "yes" will not say which.
            pendingDepartures.removeAll { nowMs - it.atMs > BOARDING_CHECK_MAX_AGE_MS }
            pendingDepartures += Departure(nowMs, vehicleId, reportedByEta = byEta)
            if (userWasAtStop && nowMs - pendingCheckSinceMs >= DEPARTURE_DEDUPE_MS) {
                // Long enough after the last time of asking to ask afresh.
                pendingCheckSinceMs = nowMs
                pendingCheckAnchor = recentUser.lastOrNull()
            }
            return
        }
        if (!userWasAtStop) {
            return
        }
        pendingCheckSinceMs = nowMs
        pendingDepartures.clear()
        pendingDepartures += Departure(nowMs, vehicleId, reportedByEta = byEta)
        pendingCheckAnchor = recentUser.lastOrNull()
    }

    /**
     * Whether this report is of a departure the rider's last "not yet" already
     * covered, reaching the app a second time.
     */
    private fun answeredByTheLastDecline(vehicleId: String?, nowMs: Long, byEta: Boolean): Boolean {
        // The window runs from the departure, not from the answer: a rider may
        // take minutes to reply, and what leaves the stop after that is the
        // next bus.
        declinedDepartures.removeAll { nowMs - it.atMs >= DEPARTURE_DEDUPE_MS }
        if (vehicleId == null) {
            // The ETA catching up with a bus the rider has answered for. Each
            // bus rolls the ETA over once, so each is caught up with once: a
            // rollover beyond that is another bus leaving.
            val awaited = declinedDepartures.firstOrNull { !it.reportedByEta }
            if (awaited != null) {
                awaited.reportedByEta = true
                return true
            }
            if (declinedRideAtMs != 0L && nowMs - declinedRideAtMs < DEPARTURE_DEDUPE_MS) {
                declinedRideAtMs = 0L
                return true
            }
            return false
        }
        if (byEta) {
            // A second rollover, with a plate: not the echo of the first.
            return false
        }
        // The question came from the ETA alone, so the answer had no vehicle to
        // be held against. This is that bus, now named — unless it was still
        // at the stop after that one had gone.
        val unnamed = declinedDepartures.firstOrNull { it.vehicleId == null } ?: return false
        if (wasAtTheStopAfter(vehicleId, unnamed.atMs)) {
            return false
        }
        unnamed.vehicleId = vehicleId
        rejectedAt[vehicleId] = lastDeclineAtMs
        return true
    }

    /**
     * Whether this report is the other feed's account, or a repeat, of a
     * departure the pending question already covers.
     */
    private fun coveredByThePendingQuestion(vehicleId: String?, nowMs: Long, byEta: Boolean): Boolean {
        if (vehicleId != null) {
            val same = pendingDepartures.firstOrNull { it.vehicleId == vehicleId }
            if (same != null) {
                same.reportedByEta = same.reportedByEta || byEta
                return true
            }
        }
        val recent = pendingDepartures.filter { nowMs - it.atMs < DEPARTURE_DEDUPE_MS }
        if (vehicleId == null) {
            // A rollover naming nothing, beside a bus the position feed saw
            // leave: probably that bus, possibly another.
            val unreported = recent.firstOrNull { !it.reportedByEta } ?: return false
            unreported.reportedByEta = true
            unreported.mayBeTwoBuses = true
            return true
        }
        if (byEta) {
            return false
        }
        // The position feed reporting a bus beside a rollover that named
        // nothing. One still at the stop after the rollover is another bus.
        val unnamed = recent.firstOrNull { it.vehicleId == null } ?: return false
        if (wasAtTheStopAfter(vehicleId, unnamed.atMs)) {
            return false
        }
        unnamed.vehicleId = vehicleId
        unnamed.mayBeTwoBuses = true
        return true
    }

    /** Whether [vehicleId] reported itself at or short of the boarding stop later than [atMs]. */
    private fun wasAtTheStopAfter(vehicleId: String, atMs: Long): Boolean {
        val boardingStop = boardingIndex
        if (boardingStop < 0) {
            return false
        }
        val boardingAlong = line.alongOfStop(boardingStop)
        return busTracks[vehicleId].orEmpty().any { sample ->
            sample.samePath && sample.onRoute && sample.gpsTimeMs > atMs &&
                sample.alongMeters - boardingAlong <= AT_STOP_MARGIN_METERS
        }
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
        pendingDepartures.clear()
        pendingCheckAnchor = null
    }

    /**
     * Once on board, the vehicle to follow is the one the user is inside. It
     * is on this trip's direction and on the route: a vehicle parked beside
     * the route projects onto it too, and can be the nearest one there is.
     *
     * A vehicle is held against where the rider was when it made its report,
     * not against where the rider is now: a report is half a minute old by the
     * time it arrives, and the two have both moved on since. The bounds are
     * wide all the same — the vehicle's clock and the phone's can disagree by
     * several seconds, which at speed is a long way.
     *
     * So a vehicle the ride is already on is given up only when the rider's
     * track shows them somewhere else at the time of its report. With no fix
     * from around then there is nothing to show that: the phone going quiet
     * while the bus drives on leaves the last fix at the boarding stop, beside
     * whichever bus pulls in next, and that is not the rider getting off one
     * and on to the other. Nor is a vehicle's own feed going quiet, or one
     * bad report from it, a reason to take up the nearest bus still reporting.
     *
     * A bus the rider has said they are not on is never picked, whatever is
     * near: "I have boarded" confirms a ride, and says nothing to take that
     * answer back.
     */
    private fun resolveTrackedVehicle(
        vehicles: List<LiveVehicle>,
        usableUser: UserSample?,
        nowMs: Long,
    ): String? {
        if (!boarded) {
            return null
        }
        val current = trackedVehicleId?.takeUnless { isRejected(it, nowMs) }
        if (usableUser == null) {
            // Remember the ride through an outage or an invalid report, but
            // only a fresh, valid report supplies progress in snapshot(). A
            // manual confirmation may also precede the first vehicle response.
            return current ?: if (evidence == BoardingEvidence.USER_CONFIRMED) {
                identifyBoardingVehicle(nowMs)
            } else {
                null
            }
        }
        val placed = vehicles.filter {
            it.samePath && it.onRoute && !it.positionUnconfirmed && !isRejected(it.vehicleId, nowMs)
        }
        val locked = placed.firstOrNull { it.vehicleId == current }
        if (locked != null) {
            val ahead = riderAheadOf(locked)
            if (ahead == null || ahead in -TRACK_MAX_AHEAD_METERS..TRACK_KEEP_BEHIND_METERS) {
                return locked.vehicleId
            }
        } else if (current != null && busTracks.containsKey(current)) {
            // Heard from within the last few minutes, but not usably placed
            // now: nothing to hold the rider's position against.
            return current
        }
        val other = placed
            .mapNotNull { vehicle -> riderAheadOf(vehicle)?.let { vehicle.vehicleId to it } }
            .filter { (_, ahead) -> ahead in -TRACK_MAX_AHEAD_METERS..TRACK_PICK_BEHIND_METERS }
            .minByOrNull { (_, ahead) -> abs(ahead) }
            ?.first
        // A vehicle shown not to be the rider's is dropped even with no other
        // to take its place; one that has simply not been heard from for
        // minutes stays until another fits.
        return other ?: current.takeIf { locked == null }
    }

    /**
     * How far ahead of [vehicle] the rider was at the moment it made its
     * latest report; null when the rider's track does not say where they were
     * then.
     */
    private fun riderAheadOf(vehicle: LiveVehicle): Double? =
        userAt(vehicle.gpsTimeMs)?.let { it.alongMeters - vehicle.alongMeters }

    /**
     * Associates an unprompted "I have boarded" with a vehicle, not just a
     * route.
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
     *
     * Nor is it a bus the app had already watched leave by then: whether the
     * rider was on that one is what the boarding question asks.
     *
     * And it must be the only bus there. With another at the stop, just gone
     * from it, or near enough to have pulled in, the rider can be on either.
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
            if (!vehicle.samePath || !vehicle.onRoute || vehicle.positionUnconfirmed ||
                isRejected(vehicle.vehicleId, nowMs) ||
                vehicle.alongMeters - boardingAlong !in -AT_STOP_MARGIN_METERS..MANUAL_VEHICLE_MAX_AHEAD_METERS
            ) {
                return@filter false
            }
            val track = busTracks[vehicle.vehicleId] ?: return@filter false
            val latest = track.lastOrNull() ?: return@filter false
            if (nowMs - latest.receivedAtMs !in 0L..MANUAL_VEHICLE_EVIDENCE_MAX_AGE_MS) {
                return@filter false
            }
            val run = track.reversed().takeWhile { it.samePath && it.onRoute }
            // A bus already seen pulling away before the rider spoke up is one
            // the app knew had gone: whether they were on it is what the
            // boarding question asks, and only an answer to that settles it.
            val hadLeftBeforeConfirming = run.any { sample ->
                sample.gpsTimeMs <= confirmedAt && sample.alongMeters - boardingAlong > LEFT_STOP_MARGIN_METERS
            }
            !hadLeftBeforeConfirming && run.any { sample ->
                confirmedAt - sample.gpsTimeMs in 0L..MANUAL_VEHICLE_EVIDENCE_MAX_AGE_MS &&
                    abs(sample.alongMeters - boardingAlong) <= AT_STOP_MARGIN_METERS &&
                    line.metersToStop(sample.latitude, sample.longitude, boardingStop) <=
                    MANUAL_AT_STOP_RADIUS_METERS
            }
        }
        val candidate = candidates.singleOrNull()
        if (candidates.size > 1 ||
            (candidate != null && anotherBusIsBoardable(confirmedAt, boardingAlong, candidate.vehicleId))
        ) {
            // Which of them the rider took is not something a later report
            // settles: one leaving the distance bound first proves nothing. A
            // usable phone fix can still identify the ride through
            // resolveTrackedVehicle().
            manualVehicleAmbiguous = true
            return null
        }
        return candidate?.vehicleId
    }

    /**
     * Whether the feeds place a vehicle other than [except] where the rider
     * could have boarded it around [atMs]: at the boarding stop, just pulling
     * away from it, or near enough short of it to have pulled in since — a
     * report is half a minute old by the time it arrives. A bus the rider has
     * turned down is not one of them.
     *
     * Either feed can place it there. A bus with no position feed is known
     * only by the stop feed's word, and is no less boardable for that.
     */
    private fun anotherBusIsBoardable(atMs: Long, boardingAlong: Double, except: String): Boolean {
        if (theStopFeedHadAnotherBusThere(atMs, except)) {
            return true
        }
        return busTracks.any { (vehicleId, track) ->
            if (vehicleId == except || isRejected(vehicleId, atMs)) {
                return@any false
            }
            val last = track.lastOrNull { it.gpsTimeMs <= atMs } ?: return@any false
            last.samePath && last.onRoute &&
                atMs - last.receivedAtMs <= BUS_REPORT_STALE_MS &&
                last.alongMeters - boardingAlong in -BOARDABLE_APPROACH_METERS..MANUAL_VEHICLE_MAX_AHEAD_METERS
        }
    }

    private fun liveVehicles(nowMs: Long): List<LiveVehicle> {
        return busTracks.entries.mapNotNull { (vehicleId, track) ->
            val last = track.lastOrNull() ?: return@mapNotNull null
            val leap = unconfirmedLeaps[vehicleId]
            val heardAtMs = maxOf(last.receivedAtMs, leap?.receivedAtMs ?: 0L)
            if (nowMs - heardAtMs > BUS_REPORT_STALE_MS) {
                return@mapNotNull null
            }
            LiveVehicle(
                vehicleId = vehicleId,
                alongMeters = last.alongMeters,
                samePath = last.samePath,
                onRoute = last.onRoute,
                receivedAtMs = heardAtMs,
                gpsTimeMs = last.gpsTimeMs,
                positionUnconfirmed = leap != null,
            )
        }
    }

    /**
     * Where the user was at [timestampMs].
     *
     * A fix made at that very moment is the answer, however long it had been
     * since the one before. Between two fixes no more than
     * [MAX_INTERPOLATION_SPAN_MS] apart it is a point on the line from one to
     * the other. Otherwise the nearer fix stands for it only if it was made
     * within [INTERPOLATION_TOLERANCE_MS] of the moment: across a longer gap
     * there is no guessing where the user was in between. Fixes older than
     * [notBeforeMs] are not looked at.
     */
    private fun userAt(timestampMs: Long, notBeforeMs: Long = Long.MIN_VALUE): UserPosition? {
        var before: UserSample? = null
        var after: UserSample? = null
        for (sample in userTrack) {
            if (sample.timestampMs < notBeforeMs) {
                continue
            }
            if (sample.timestampMs >= timestampMs) {
                after = sample
                break
            }
            before = sample
        }
        if (after != null && after.timestampMs == timestampMs) {
            return UserPosition(after.alongMeters, after.onRoute)
        }
        if (before != null && after != null) {
            val spanMs = after.timestampMs - before.timestampMs
            if (spanMs <= MAX_INTERPOLATION_SPAN_MS) {
                val fraction = (timestampMs - before.timestampMs).toDouble() / spanMs
                return UserPosition(
                    alongMeters = before.alongMeters + fraction * (after.alongMeters - before.alongMeters),
                    onRoute = before.onRoute && after.onRoute,
                )
            }
        }
        val nearest = listOfNotNull(before, after)
            .minByOrNull { abs(it.timestampMs - timestampMs) }
            ?.takeIf { abs(it.timestampMs - timestampMs) <= INTERPOLATION_TOLERANCE_MS }
            ?: return null
        return UserPosition(nearest.alongMeters, nearest.onRoute)
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
        unconfirmedLeaps.keys.retainAll(busTracks.keys)
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
        val onRoute: Boolean,
    )

    /** The user's along-route position at some moment, and whether they were on the route. */
    private data class UserPosition(val alongMeters: Double, val onRoute: Boolean)

    private data class BusSample(
        val latitude: Double,
        val longitude: Double,
        val alongMeters: Double,
        val gpsTimeMs: Long,
        val receivedAtMs: Long,
        val samePath: Boolean,
        val onRoute: Boolean,
        /** The vehicle reached this position by a leap no bus could drive; see [onBusReports]. */
        val startsNewStretch: Boolean = false,
    )

    /** When the stop feed first and last placed a bus at the boarding stop. */
    private class StopPresence(val sinceMs: Long, var untilMs: Long = sinceMs)

    /**
     * One bus leaving the boarding stop. [vehicleId] is set once a feed has
     * named it, [reportedByEta] once the ETA rolling over has reported it.
     * [mayBeTwoBuses] marks a position report and an unnamed rollover taken
     * together without anything to show they were the same bus.
     */
    private class Departure(
        val atMs: Long,
        var vehicleId: String?,
        var reportedByEta: Boolean,
        var mayBeTwoBuses: Boolean = false,
    )

    private data class LiveVehicle(
        val vehicleId: String,
        val alongMeters: Double,
        val samePath: Boolean,
        val onRoute: Boolean,
        val receivedAtMs: Long,
        /** When the vehicle was at [alongMeters], by its own clock. */
        val gpsTimeMs: Long,
        /** Its latest report put it somewhere no bus could have driven to; [alongMeters] is where it was before. */
        val positionUnconfirmed: Boolean = false,
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

        /**
         * The furthest a vehicle is believed to have gone between two reports.
         * City buses in the recorded feeds reach 19 m/s at the 99.9th
         * percentile; 35 m/s leaves room for a motorway stretch, and the fixed
         * allowance for GPS error over a short interval.
         */
        const val MAX_PLAUSIBLE_BUS_SPEED_MPS = 35.0
        const val MAX_BUS_STEP_ALLOWANCE_METERS = 150.0
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

        /**
         * How much further along the route than over the ground a run of fixes
         * may have gone. The route is drawn stop to stop, so rounding a corner
         * between two fixes covers more of it than the straight line between
         * them — but not several times more.
         */
        const val SELF_PROGRESS_MAX_STRETCH = 2.0
        const val SELF_PROGRESS_STRETCH_ALLOWANCE_METERS = 100.0

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
        const val BOARDABLE_APPROACH_METERS = 300.0

        const val ETA_ARRIVING_SECONDS = 30
        const val ETA_ROLLOVER_SECONDS = 240
        const val ETA_ROLLOVER_WINDOW_MS = 150_000L

        /**
         * How long after the last live estimate one that has run out still
         * says a bus is due. In recorded feeds the run-out estimate lasted
         * under a minute in all but a handful of cases.
         */
        const val ETA_RAN_OUT_MAX_MS = 90_000L

        /** How far behind the street a poll of the stop feed may be. */
        const val STOP_FEED_LAG_MS = 30_000L

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
