package tw.avianjay.taiwanbus.flutter

import kotlin.math.PI
import kotlin.math.cos
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * "還沒上車" is an answer about one bus, not about the trip.
 *
 * It used to switch automatic detection off until the trip was rebuilt, so the
 * bus the rider was actually waiting for — usually the next one along, minutes
 * behind the one they turned down — was never detected, no boarding alert
 * fired, and the destination reminders never armed.
 *
 * The route is a straight northbound line of five stops 500 m apart, and the
 * rider waits at the first one, wandering off it: a phone that never moves is
 * read as "still waiting" and is deliberately never asked anything.
 */
class TripRideDetectorDeclineTest {
    @Test
    fun decliningOneBusStillDetectsTheNext() {
        val detector = newDetector()
        var declinedAtMs = 0L
        var promptsAfterTheAnswer = 0
        var boardedAtMs = 0L
        var boardedVehicleId: String? = null

        detector.feed(firstWaitThenRide(), listOf(declinedBusRun(), nextBusRun()), 0, 560) { nowMs, snapshot ->
            if (declinedAtMs == 0L) {
                if (snapshot.boardingPromptDue) {
                    // The question the rider answers with "還沒上車", asked about
                    // the first bus to leave the stop.
                    detector.declineBoarding(nowMs)
                    declinedAtMs = nowMs
                }
            } else if (boardedAtMs == 0L && snapshot.boardingPromptDue) {
                promptsAfterTheAnswer++
            }
            if (boardedAtMs == 0L && snapshot.hasBoarded) {
                boardedAtMs = nowMs
                boardedVehicleId = snapshot.trackedVehicleId
            }
        }

        assertTrue("expected the rider to be asked about the first bus", declinedAtMs > 0L)
        assertEquals(
            "the bus that was turned down must not be asked about again",
            0,
            promptsAfterTheAnswer,
        )
        assertTrue("boarding the next bus must still be detected", boardedAtMs > 0L)
        assertEquals("and the ride must latch onto the bus actually ridden", NEXT_BUS, boardedVehicleId)
    }

    @Test
    fun theBoardingQuestionComesBackForTheNextBus() {
        val detector = newDetector()
        var declinedAtMs = 0L
        var askedAboutTheNextBus = false
        var boarded = false

        detector.feed(firstWaitThenWatch(), listOf(declinedBusRun(), nextBusRun()), 0, 520) { nowMs, snapshot ->
            if (declinedAtMs == 0L) {
                if (snapshot.boardingPromptDue) {
                    detector.declineBoarding(nowMs)
                    declinedAtMs = nowMs
                }
            } else if (snapshot.boardingPromptDue) {
                askedAboutTheNextBus = true
            }
            if (snapshot.hasBoarded) {
                boarded = true
            }
        }

        assertTrue("expected the rider to be asked about the first bus", declinedAtMs > 0L)
        assertFalse("the rider never got on", boarded)
        assertTrue(
            "turning down one bus must not silence the question for the next one",
            askedAboutTheNextBus,
        )
    }

    @Test
    fun aTurnedDownVehicleCanBeDetectedAgainOnceItsRejectionLapses() {
        val detector = newDetector()
        var declinedAtMs = 0L
        var boardedAtMs = 0L
        var boardedVehicleId: String? = null

        // The same vehicle on its next run, which begins while it is still
        // turned down. Only the rejection lapsing lets the ride be detected, so
        // the feed stops the moment it should be — a longer feed would let the
        // rider's own progress detect the ride instead and hide the bug.
        detector.feed(waitingForItsNextRun(), listOf(declinedBusRun(), returnedRun()), 0, 1440) { nowMs, snapshot ->
            if (declinedAtMs == 0L) {
                if (snapshot.boardingPromptDue) {
                    detector.declineBoarding(nowMs)
                    declinedAtMs = nowMs
                }
            }
            if (boardedAtMs == 0L && snapshot.hasBoarded) {
                boardedAtMs = nowMs
                boardedVehicleId = snapshot.trackedVehicleId
            }
        }

        assertTrue("expected the rider to be asked about the first bus", declinedAtMs > 0L)
        assertTrue(
            "the same vehicle must be detectable once its rejection has lapsed",
            boardedAtMs > 0L,
        )
        assertEquals(DECLINED_BUS, boardedVehicleId)
        assertTrue(
            "detected ${(boardedAtMs - declinedAtMs) / 1000}s after the answer, which is inside " +
                "the 1200s rejection — this run only proves the lapse if the ride is detected " +
                "after it",
            boardedAtMs - declinedAtMs > 1_200_000L,
        )
    }

    @Test
    fun confirmingByHandOutranksATurnedDownVehicle() {
        val detector = newDetector()
        var declinedAtMs = 0L
        var confirmed = false
        var boarded = false

        detector.feed(firstWaitThenWatch(), listOf(declinedBusRun(), nextBusRun()), 0, 400) { nowMs, snapshot ->
            if (declinedAtMs == 0L) {
                if (snapshot.boardingPromptDue) {
                    detector.declineBoarding(nowMs)
                    declinedAtMs = nowMs
                }
            } else if (!confirmed && nowMs >= at(300)) {
                // The rider stops waiting on detection and taps the manual
                // action, exactly as the notification does.
                detector.confirmBoardedByUser(nowMs)
                confirmed = true
            }
            if (snapshot.hasBoarded) {
                boarded = true
            }
        }

        assertTrue("expected the rider to be asked about the first bus", declinedAtMs > 0L)
        assertTrue(confirmed)
        assertTrue("the manual action has to keep working after a decline", boarded)
    }

    @Test
    fun theSameDepartureEchoedByTheEtaFeedIsNotAskedAboutTwice() {
        // No location at all, so asking is the only tool and nothing else can
        // quiet the question.
        val detector = newDetector()
        detector.leaveTheStop(DECLINED_BUS, fromSeconds = 0)
        detector.onBoardingStopEta(etaSeconds = 0, arriving = true, nowMs = at(20))
        assertTrue(detector.snapshot(at(80)).boardingPromptDue)
        detector.declineBoarding(at(80))

        // The ETA rolling over to the next bus is the same departure, late.
        detector.onBoardingStopEta(etaSeconds = 600, arriving = false, nowMs = at(100))

        assertFalse(detector.snapshot(at(140)).boardingPromptDue)
    }

    @Test
    fun aLateAnswerDoesNotSwallowTheNextDeparture() {
        val detector = newDetector()
        detector.leaveTheStop(DECLINED_BUS, fromSeconds = 0)
        // The rider gets round to the question four minutes later.
        assertTrue(detector.snapshot(at(280)).boardingPromptDue)
        detector.declineBoarding(at(280))

        // Moments after the answer the next bus pulls in and leaves; it has no
        // position feed, so the ETA is all that reports it.
        detector.onBoardingStopEta(etaSeconds = 0, arriving = true, nowMs = at(290))
        detector.onBoardingStopEta(etaSeconds = 600, arriving = false, nowMs = at(310))

        assertTrue(
            "the next bus must be asked about however late the last answer came",
            detector.snapshot(at(350)).boardingPromptDue,
        )
    }

    /** A bus pulls in at the boarding stop and drives off, 20 s a report. */
    private fun TripRideDetector.leaveTheStop(vehicleId: String, fromSeconds: Long) {
        val run = busRun(
            vehicleId,
            fromSeconds to 10.0,
            fromSeconds + 20 to 30.0,
            fromSeconds + 40 to 150.0,
        )
        for (seconds in fromSeconds..fromSeconds + 40 step 20) {
            onBusReports(run.reportsAt(at(seconds)))
            snapshot(at(seconds))
        }
    }

    private fun newDetector() = TripRideDetector(
        stops = routeStops(),
        pathId = 0,
        boardingStopId = BOARDING_STOP_ID,
        destinationStopId = BOARDING_STOP_ID + 4,
    )
}

private const val BOARDING_STOP_ID = 900

/** An arbitrary wall-clock instant, aligned to the 20 s poll grid below. */
private const val BASE_MS = 1_700_000_000_000L

private const val DECLINED_BUS = "AAA-001"
private const val NEXT_BUS = "BBB-002"

private fun at(seconds: Long): Long = BASE_MS + seconds * 1_000L

private val METERS_PER_DEGREE_LAT = 6_371_000.0 * PI / 180.0
private val METERS_PER_DEGREE_LON = METERS_PER_DEGREE_LAT * cos(24.0 * PI / 180.0)

/** [offsetMeters] is measured east of the route, which runs due north. */
private fun point(alongMeters: Double, offsetMeters: Double): Pair<Double, Double> =
    24.0 + alongMeters / METERS_PER_DEGREE_LAT to 120.5 + offsetMeters / METERS_PER_DEGREE_LON

private fun routeStops(): List<TrackingStop> = (0..4).map { index ->
    val (lat, lon) = point(index * 500.0, 0.0)
    TrackingStop(
        stopId = BOARDING_STOP_ID + index,
        stopName = "stop-$index",
        sequence = index,
        lat = lat,
        lon = lon,
    )
}

/** The rider's path as waypoints, linearly interpolated by the frame clock. */
private class UserPath(private val waypoints: List<Waypoint>) {
    data class Waypoint(
        val tMs: Long,
        val alongMeters: Double,
        val offsetMeters: Double,
        val speedMetersPerSecond: Float,
    )

    fun fix(tMs: Long): RideGeoPoint {
        val index = waypoints.indexOfLast { it.tMs <= tMs }.coerceAtLeast(0)
        val from = waypoints[index]
        val to = waypoints[(index + 1).coerceAtMost(waypoints.lastIndex)]
        val span = (to.tMs - from.tMs).toDouble()
        val fraction = if (span <= 0.0) 0.0 else ((tMs - from.tMs) / span).coerceIn(0.0, 1.0)
        val (lat, lon) = point(
            from.alongMeters + fraction * (to.alongMeters - from.alongMeters),
            from.offsetMeters + fraction * (to.offsetMeters - from.offsetMeters),
        )
        return RideGeoPoint(
            latitude = lat,
            longitude = lon,
            timestampMs = tMs,
            accuracyMeters = 12f,
            speedMetersPerSecond = from.speedMetersPerSecond,
        )
    }
}

private fun path(vararg waypoints: UserPath.Waypoint) = UserPath(waypoints.toList())

private fun step(seconds: Long, along: Double, offset: Double, speed: Float) =
    UserPath.Waypoint(at(seconds), along, offset, speed)

/** One bus's positions, keyed by the poll they were first seen in. */
private class BusRun(val vehicleId: String, positions: List<Pair<Long, Double>>) {
    private val alongByTime = positions.toMap()

    fun reportsAt(tMs: Long): List<RideBusReport> {
        val along = alongByTime[tMs] ?: return emptyList()
        val (lat, lon) = point(along, 0.0)
        return listOf(
            RideBusReport(
                vehicleId = vehicleId,
                pathId = 0,
                latitude = lat,
                longitude = lon,
                gpsTimeMs = tMs,
                receivedAtMs = tMs,
            ),
        )
    }
}

private fun busRun(vehicleId: String, vararg positions: Pair<Long, Double>) =
    BusRun(vehicleId, positions.map { at(it.first) to it.second })

/**
 * Pulls in at the boarding stop, is turned down, and drives away. It keeps
 * reporting while it leaves, which is what the rejection is scoped to.
 */
private fun declinedBusRun() = busRun(
    DECLINED_BUS,
    40L to 10.0,
    60L to 30.0,
    80L to 100.0,
    100L to 150.0,
    120L to 250.0,
    140L to 350.0,
)

/** The bus the rider actually takes, five minutes behind the one they refused. */
private fun nextBusRun() = busRun(
    NEXT_BUS,
    340L to 10.0,
    360L to 25.0,
    380L to 35.0,
    400L to 45.0,
    420L to 130.0,
    440L to 230.0,
    460L to 330.0,
    480L to 430.0,
    500L to 530.0,
    520L to 630.0,
    540L to 730.0,
    560L to 830.0,
)

/**
 * The same vehicle on its next run, which starts 19 minutes after it was
 * refused — before the rejection lapses — and leaves the stop after it has.
 */
private fun returnedRun() = busRun(
    DECLINED_BUS,
    1300L to 10.0,
    1320L to 15.0,
    1340L to 20.0,
    1360L to 25.0,
    1380L to 30.0,
    1400L to 130.0,
    1420L to 230.0,
    1440L to 330.0,
)

/**
 * Wanders 250 m off the stop — enough that the app cannot call it "still
 * waiting" — comes back, and rides the next bus at 5 m/s.
 */
private fun firstWaitThenRide() = path(
    step(0, along = 0.0, offset = 0.0, speed = 0.3f),
    step(80, along = 0.0, offset = 0.0, speed = 2.5f),
    step(180, along = 0.0, offset = 250.0, speed = 2.5f),
    step(200, along = 0.0, offset = 240.0, speed = 1.15f),
    step(400, along = 0.0, offset = 0.0, speed = 1.15f),
    step(420, along = 100.0, offset = 0.0, speed = 5f),
    step(560, along = 800.0, offset = 0.0, speed = 5f),
)

/** The same wait, but the rider wanders away instead of boarding. */
private fun firstWaitThenWatch() = path(
    step(0, along = 0.0, offset = 0.0, speed = 0.3f),
    step(80, along = 0.0, offset = 0.0, speed = 2.5f),
    step(180, along = 0.0, offset = 250.0, speed = 2.5f),
    step(200, along = 0.0, offset = 240.0, speed = 1.15f),
    step(400, along = 0.0, offset = 0.0, speed = 1.15f),
    step(420, along = 0.0, offset = 0.0, speed = 2.5f),
    step(520, along = 0.0, offset = 250.0, speed = 2.5f),
)

/**
 * Waits at the stop for the same vehicle's next run and boards it as it leaves.
 * The ride is short on purpose — under 500 m of travel, so that co-movement is
 * the only layer that can detect it and the vehicle's rejection is the one
 * thing standing in the way.
 */
private fun waitingForItsNextRun() = path(
    step(0, along = 0.0, offset = 0.0, speed = 0.3f),
    step(80, along = 0.0, offset = 0.0, speed = 2.5f),
    step(180, along = 0.0, offset = 250.0, speed = 2.5f),
    step(200, along = 0.0, offset = 240.0, speed = 1.15f),
    step(400, along = 0.0, offset = 0.0, speed = 1.15f),
    step(1380, along = 0.0, offset = 0.0, speed = 0.3f),
    step(1400, along = 100.0, offset = 0.0, speed = 5f),
    step(1440, along = 300.0, offset = 0.0, speed = 5f),
)

/**
 * Feeds the polls in time order, as the service does: the frame's bus reports
 * first, then the rider's fix, then the snapshot the app would take.
 */
private fun TripRideDetector.feed(
    userPath: UserPath,
    buses: List<BusRun>,
    fromSeconds: Long,
    toSeconds: Long,
    onFrame: (Long, RideSnapshot) -> Unit,
) {
    var seconds = fromSeconds
    while (seconds <= toSeconds) {
        val nowMs = at(seconds)
        buses.forEach { onBusReports(it.reportsAt(nowMs)) }
        onUserLocation(userPath.fix(nowMs))
        onFrame(nowMs, snapshot(nowMs))
        seconds += 20
    }
}
