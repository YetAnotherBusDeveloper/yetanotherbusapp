package tw.avianjay.taiwanbus.flutter

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.double
import kotlinx.serialization.json.float
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Replays recorded live feeds through [TripRideDetector].
 *
 * Each fixture is a real capture of `/realtime/buses` and `/realtime` for one
 * route: a synthetic passenger waits at a stop and then rides one of the
 * recorded vehicles, while two negative controls are on the same street without
 * being on the bus — waiting at the stop (with urban-canyon GPS noise), and
 * walking the route.
 */
class TripRideDetectorReplayTest {
    @Test
    fun detectsRidingATaichungBus() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val result = replay.detect(replay.riderFixes)

        assertTrue("expected the ride to be detected", result.detected)
        assertTrue(
            "detected ${(result.detectedAtMs - replay.boardedAtMs) / 1000}s after boarding",
            result.detectedAtMs - replay.boardedAtMs <= 180_000L,
        )
    }

    @Test
    fun detectsRidingAKaohsiungBus() {
        val replay = Replay.load("ride_replay_KHH100_0")
        val result = replay.detect(replay.riderFixes)

        assertTrue("expected the ride to be detected", result.detected)
        assertTrue(
            "detected ${(result.detectedAtMs - replay.boardedAtMs) / 1000}s after boarding",
            result.detectedAtMs - replay.boardedAtMs <= 180_000L,
        )
    }

    @Test
    fun detectsRidingATaipeiBusWhoseEtaFeedHasNoPlates() {
        val replay = Replay.load("ride_replay_TPE157463_0")
        val result = replay.detect(replay.riderFixes)

        assertTrue("expected the ride to be detected", result.detected)
        assertTrue(
            "detected ${(result.detectedAtMs - replay.boardedAtMs) / 1000}s after boarding",
            result.detectedAtMs - replay.boardedAtMs <= 180_000L,
        )
    }

    @Test
    fun ridesTheRecordedVehicle() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val result = replay.detect(replay.riderFixes)

        assertTrue(result.detected)
        assertEquals(replay.plate, result.trackedVehicleId)
    }

    @Test
    fun doesNotDetectWaitingAtTheBoardingStop() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val result = replay.detect(replay.waitingFixes)

        assertFalse("waiting at the stop must never count as boarding", result.detected)
    }

    @Test
    fun doesNotDetectWaitingAtTheBoardingStopInTaipei() {
        val replay = Replay.load("ride_replay_TPE157463_0")
        val result = replay.detect(replay.waitingFixes)

        assertFalse("waiting at the stop must never count as boarding", result.detected)
    }

    @Test
    fun doesNotDetectWalkingAlongTheRoute() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val result = replay.detect(replay.walkerFixes)

        assertFalse("walking the same street must never count as boarding", result.detected)
    }

    @Test
    fun doesNotDetectWalkingAlongTheRouteInTaipei() {
        val replay = Replay.load("ride_replay_TPE157463_0")
        val result = replay.detect(replay.walkerFixes)

        assertFalse("walking the same street must never count as boarding", result.detected)
    }

    @Test
    fun asksTheUserAfterABusLeavesTheBoardingStop() {
        val replay = Replay.load("ride_replay_TXG300_0")
        // The user drifts around the stop, as a phone in a pocket does, and
        // eventually wanders off down the street — so the app cannot conclude
        // from stillness alone that they are still waiting.
        val drifting = replay.waitingFixes.mapIndexed { index, fix ->
            if (index < replay.waitingFixes.size / 2) fix else replay.walkerFixes[index]
        }
        var prompted = false
        val result = replay.detect(drifting) { _, snapshot ->
            if (snapshot.boardingPromptDue) {
                prompted = true
            }
        }

        assertTrue("a passenger who never boarded should be asked", prompted)
        assertFalse("walking away from the stop is not a ride", result.detected)
    }

    @Test
    fun doesNotAskWhileTheUserIsStillRiding() {
        val replay = Replay.load("ride_replay_TXG300_0")
        var askedWhileRiding = false
        val result = replay.detect(replay.riderFixes) { _, snapshot ->
            if (snapshot.hasBoarded && snapshot.boardingPromptDue) {
                askedWhileRiding = true
            }
        }

        assertTrue("expected the ride to be detected", result.detected)
        assertFalse("a confirmed ride must not be questioned", askedWhileRiding)
    }

    @Test
    fun asksEvenWhenTheBusPositionFeedIsEmpty() {
        val replay = Replay.load("ride_replay_TPE157463_0")
        var prompted = false
        replay.detect(replay.waitingFixes, withBusReports = false) { _, snapshot ->
            if (snapshot.boardingPromptDue) {
                prompted = true
            }
        }

        assertTrue("the ETA feed alone must be able to raise the question", prompted)
    }

    @Test
    fun userConfirmationWinsOverEverything() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val detector = replay.detector()
        replay.pump(detector, withBusReports = true, withUserFixes = false) { _, _ -> }

        detector.confirmBoardedByUser(replay.lastFrameMs)

        val snapshot = detector.snapshot(replay.lastFrameMs)
        assertTrue(snapshot.hasBoarded)
        assertEquals(BoardingEvidence.USER_CONFIRMED, snapshot.evidence)
        assertFalse(snapshot.boardingPromptDue)
    }

    @Test
    fun aDeclineIsNotOverruledByTheEvidenceItAnswered() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val detector = replay.detector()
        var declined = false
        val looksAfterTheAnswer = ArrayList<RideSnapshot>()
        replay.pump(detector, withUserFixes = true) { nowMs, snapshot ->
            if (!declined && snapshot.hasBoarded) {
                // Everything that detected this ride is still in the detector's
                // window when the rider says no.
                detector.declineBoarding(nowMs)
                declined = true
                looksAfterTheAnswer += detector.snapshot(nowMs)
            } else if (declined && looksAfterTheAnswer.size < 2) {
                looksAfterTheAnswer += snapshot
            }
        }

        assertTrue("expected the recorded ride to be detected", declined)
        assertEquals(2, looksAfterTheAnswer.size)
        looksAfterTheAnswer.forEach { snapshot ->
            assertFalse("the answer holds at the next look", snapshot.hasBoarded)
            assertEquals(BoardingEvidence.NONE, snapshot.evidence)
        }
    }

    @Test
    fun remainingStopsCountDownAndNeverGoNegative() {
        val replay = Replay.load("ride_replay_TXG300_0")
        var previous = Int.MAX_VALUE
        var observed = false
        replay.detect(replay.riderFixes) { _, snapshot ->
            val remaining = snapshot.remainingStops ?: return@detect
            observed = true
            assertTrue("remainingStops grew: $previous -> $remaining", remaining <= previous)
            assertTrue("remainingStops went negative: $remaining", remaining >= 0)
            previous = remaining
        }

        assertTrue("expected a destination to be tracked", observed)
    }

    @Test
    fun changingTheDestinationDoesNotDisturbTheRide() {
        val replay = Replay.load("ride_replay_TXG300_0")
        val detector = replay.detector()
        var changed = false
        replay.pump(detector, withUserFixes = true) { _, snapshot ->
            if (!changed && snapshot.hasBoarded) {
                detector.updateDestination(replay.destinationStopId - 1)
                changed = true
            }
        }

        assertTrue(changed)
        val snapshot = detector.snapshot(replay.lastFrameMs)
        assertTrue("the ride must survive a new destination", snapshot.hasBoarded)
        assertEquals(replay.plate, snapshot.trackedVehicleId)
    }
}

private class Replay(
    private val stops: List<TrackingStop>,
    private val pathId: Int,
    val plate: String,
    val boardedAtMs: Long,
    val destinationStopId: Int,
    private val boardingStopId: Int,
    private val frames: List<Frame>,
    val riderFixes: List<RideGeoPoint>,
    val waitingFixes: List<RideGeoPoint>,
    val walkerFixes: List<RideGeoPoint>,
) {
    /** One poll of the live feeds, at the moment the app would have made it. */
    class Frame(
        val nowMs: Long,
        val reports: List<RideBusReport>,
        val boardingEta: EtaReading?,
    )

    class EtaReading(val etaSeconds: Int?, val arriving: Boolean)

    class DetectionResult(
        val detected: Boolean,
        val detectedAtMs: Long,
        val trackedVehicleId: String?,
    )

    val lastFrameMs: Long get() = frames.last().nowMs

    fun detector(): TripRideDetector = TripRideDetector(
        stops = stops,
        pathId = pathId,
        boardingStopId = boardingStopId,
        destinationStopId = destinationStopId,
    )

    /**
     * Feeds the recorded polls and [fixes] in time order, reporting every
     * snapshot. The detector's own answer is what decides when a ride has been
     * detected, so this never reads state the app could not see.
     */
    fun detect(
        fixes: List<RideGeoPoint>,
        withBusReports: Boolean = true,
        onSnapshot: (Long, RideSnapshot) -> Unit = { _, _ -> },
    ): DetectionResult {
        val detector = detector()
        var detectedAtMs = 0L
        var trackedVehicleId: String? = null
        var fixIndex = 0
        pump(detector, withBusReports = withBusReports, withUserFixes = false) { nowMs, _ ->
            while (fixIndex < fixes.size && fixes[fixIndex].timestampMs <= nowMs) {
                detector.onUserLocation(fixes[fixIndex])
                fixIndex++
            }
            val snapshot = detector.snapshot(nowMs)
            if (detectedAtMs == 0L && snapshot.hasBoarded) {
                detectedAtMs = nowMs
                trackedVehicleId = snapshot.trackedVehicleId
            }
            onSnapshot(nowMs, snapshot)
        }
        return DetectionResult(detectedAtMs != 0L, detectedAtMs, trackedVehicleId)
    }

    /** Walks the recorded polls without feeding any user fixes. */
    fun pump(
        detector: TripRideDetector,
        withBusReports: Boolean = true,
        withUserFixes: Boolean = false,
        onSnapshot: (Long, RideSnapshot) -> Unit,
    ) {
        frames.forEach { frame ->
            if (withBusReports && frame.reports.isNotEmpty()) {
                detector.onBusReports(frame.reports)
            }
            frame.boardingEta?.let {
                detector.onBoardingStopEta(it.etaSeconds, it.arriving, frame.nowMs)
            }
            if (withUserFixes) {
                detector.onUserLocation(nearestFix(riderFixes, frame.nowMs))
            }
            onSnapshot(frame.nowMs, detector.snapshot(frame.nowMs))
        }
    }

    private fun nearestFix(fixes: List<RideGeoPoint>, nowMs: Long): RideGeoPoint {
        var low = 0
        var high = fixes.size - 1
        while (low < high) {
            val mid = (low + high) / 2
            if (fixes[mid].timestampMs < nowMs) low = mid + 1 else high = mid
        }
        return fixes[low]
    }

    companion object {
        // org.json is only a stub on the plain JVM test classpath, so fixtures
        // are read with kotlinx.serialization instead.
        fun load(name: String): Replay {
            val stream = Replay::class.java.classLoader?.getResourceAsStream("$name.json")
            val text = requireNotNull(stream) { "missing fixture $name.json" }
                .bufferedReader(Charsets.UTF_8)
                .use { it.readText() }
            val root = Json.parseToJsonElement(text).jsonObject

            val stops = root.getArray("stops").map { element ->
                val stop = element.jsonObject
                TrackingStop(
                    // Folded exactly as the service folds it, from the raw feed
                    // value. A fixture that stored pre-folded ids could not tell
                    // a correct fold from a broken one.
                    stopId = foldStopId(stop.getValue("stopIdRaw").jsonPrimitive.content),
                    stopName = "stop-${stop.getInt("sequence")}",
                    sequence = stop.getInt("sequence"),
                    lat = stop.getValue("lat").jsonPrimitive.double,
                    lon = stop.getValue("lon").jsonPrimitive.double,
                )
            }

            val reportsByFrame = root.getArray("busReports").groupBy { it.jsonObject.getLong("rx") }
            val etaByFrame = root.getArray("boardingEta").associateBy { it.jsonObject.getLong("t") }
            val frames = (reportsByFrame.keys + etaByFrame.keys).sorted().map { nowMs ->
                Frame(
                    nowMs = nowMs,
                    reports = reportsByFrame[nowMs].orEmpty().map { element ->
                        val report = element.jsonObject
                        RideBusReport(
                            vehicleId = report.getValue("id").jsonPrimitive.content,
                            pathId = report["dir"]?.jsonPrimitive?.content?.toIntOrNull(),
                            latitude = report.getValue("lat").jsonPrimitive.double,
                            longitude = report.getValue("lon").jsonPrimitive.double,
                            gpsTimeMs = report.getValue("t").jsonPrimitive.long,
                            receivedAtMs = nowMs,
                        )
                    },
                    boardingEta = etaByFrame[nowMs]?.jsonObject?.let { eta ->
                        EtaReading(
                            etaSeconds = eta["eta"]?.jsonPrimitive?.content?.toIntOrNull(),
                            arriving = eta["arriving"]?.jsonPrimitive?.boolean ?: false,
                        )
                    },
                )
            }

            return Replay(
                stops = stops,
                pathId = root.getInt("pathId"),
                plate = root.getValue("plate").jsonPrimitive.content,
                boardedAtMs = root.getValue("boardedAtMs").jsonPrimitive.long,
                destinationStopId = foldStopId(
                    root.getValue("destinationStopIdRaw").jsonPrimitive.content,
                ),
                boardingStopId = foldStopId(
                    root.getValue("boardingStopIdRaw").jsonPrimitive.content,
                ),
                frames = frames,
                riderFixes = root.fixes("riderFixes"),
                waitingFixes = root.fixes("waitingFixes"),
                walkerFixes = root.fixes("walkerFixes"),
            )
        }

        private fun JsonObject.getArray(key: String) = getValue(key).jsonArray

        private fun JsonObject.getInt(key: String) = getValue(key).jsonPrimitive.int

        private fun JsonObject.getLong(key: String) = getValue(key).jsonPrimitive.long

        private fun JsonObject.fixes(key: String): List<RideGeoPoint> {
            return getArray(key).map { element ->
                val fix = element.jsonObject
                RideGeoPoint(
                    latitude = fix.getValue("lat").jsonPrimitive.double,
                    longitude = fix.getValue("lon").jsonPrimitive.double,
                    timestampMs = fix.getValue("t").jsonPrimitive.long,
                    accuracyMeters = fix["acc"]?.jsonPrimitive?.float ?: 0f,
                    speedMetersPerSecond = fix["spd"]?.jsonPrimitive?.float,
                )
            }
        }
    }
}
