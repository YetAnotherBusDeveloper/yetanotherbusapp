package tw.avianjay.taiwanbus.flutter

import kotlin.math.PI
import kotlin.math.cos
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Projecting a fix onto a route that comes close to itself.
 *
 * Positions are given in metres east and north of the first stop. The hairpin
 * runs 1 km north, 40 m east, and 1 km back south beside the way it came, then
 * off to the east: its two long legs are 40 m apart, nearer than the slack the
 * projection allows itself for a noisy fix.
 */
class RideRouteLineTest {
    @Test
    fun travelRoundAHairpinGoesForwardAlongTheReturnLeg() {
        val line = RideRouteLine(HAIRPIN)
        // One fix at each of the first five stops, as a vehicle reporting only
        // at stops would give, each projected from where the last one came out.
        var along: Double? = null
        val reached = HAIRPIN_POINTS.take(5).map { (x, y) ->
            val projection = line.project(lat(y), lon(x), along)
            along = projection.alongMeters
            line.stopIndexAt(projection.alongMeters)
        }

        assertEquals("each stop must be reached in turn", listOf(0, 1, 2, 3, 4), reached)
    }

    @Test
    fun aFixOnTheReturnLegIsNotPulledBackOntoTheOutboundLeg() {
        val line = RideRouteLine(HAIRPIN)
        // The last position was the far end of the outbound leg; the fix now
        // lies exactly on the return leg, half way down it.
        val projection = line.project(lat(500.0), lon(40.0), 1_000.0)

        assertEquals(1_540.0, projection.alongMeters, 0.5)
        assertEquals(0.0, projection.crossTrackMeters, 0.5)
    }

    @Test
    fun aNoisyFixBesideAHairpinStaysOnTheLegBeingTravelled() {
        val line = RideRouteLine(HAIRPIN)
        // Going out, 300 m up the first leg, a fix that reads 25 m to the east:
        // nearer the return leg than the one it is on.
        val outbound = line.project(lat(320.0), lon(25.0), 300.0)
        assertEquals("still outbound", 320.0, outbound.alongMeters, 0.5)

        // Coming back, level with the same place, a fix that reads 25 m west.
        val returning = line.project(lat(320.0), lon(15.0), 1_700.0)
        assertEquals("still on the way back", 1_720.0, returning.alongMeters, 0.5)
    }

    @Test
    fun aStreetUsedTwiceIsToldApartByWhichPassContinuesTheJourney() {
        // Out along a street and back along the same one: every fix on it is
        // as near one pass as the other.
        val line = RideRouteLine(routeOf(0.0 to 0.0, 0.0 to 1_000.0, 0.0 to 0.0, 500.0 to 0.0))

        assertEquals(400.0, line.project(lat(400.0), lon(0.0), 350.0).alongMeters, 0.5)
        assertEquals(1_600.0, line.project(lat(400.0), lon(0.0), 1_550.0).alongMeters, 0.5)
    }

    @Test
    fun aBackwardGlitchDoesNotThrowTheFixOntoTheOtherLeg() {
        val line = RideRouteLine(HAIRPIN)
        // 600 m up the outbound leg, then a fix 150 m back down it. Nothing
        // has gone round the hairpin: the return leg there is 800 m further on.
        val projection = line.project(lat(450.0), lon(0.0), 600.0)

        assertEquals(450.0, projection.alongMeters, 0.5)
    }

    @Test
    fun theDistanceReportedIsToTheSegmentChosen() {
        // The last segment runs back down beside the first one, 50 m east of
        // it. A fix 640 m east is 590 m from that last segment and 640 m from
        // the first, and the first is where the route so far puts it.
        val line = RideRouteLine(routeOf(0.0 to 0.0, 0.0 to 1_000.0, 50.0 to 200.0, 50.0 to 0.0))
        val projection = line.project(lat(100.0), lon(640.0), 0.0)

        assertEquals(0, projection.segmentIndex)
        assertEquals(100.0, projection.alongMeters, 0.5)
        assertEquals(
            "the distance must be the one to the segment the position is on",
            640.0,
            projection.crossTrackMeters,
            0.5,
        )
    }

    @Test
    fun aVehicleFarOffAFoldedRouteIsNotTakenForOneOnIt() {
        val stops = routeOf(0.0 to 0.0, 0.0 to 1_000.0, 50.0 to 200.0, 50.0 to 0.0)
        val detector = TripRideDetector(stops, pathId = 0, boardingStopId = 1, destinationStopId = 4)
        detector.onBusReports(listOf(report(0, x = 0.0, y = 0.0)))
        detector.confirmBoardedByUser(at(0))
        assertEquals("BUS", detector.snapshot(at(0)).trackedVehicleId)

        // 640 m to the side of the stretch it projects onto, which allows 600.
        detector.onBusReports(listOf(report(20, x = 640.0, y = 100.0)))
        val ride = detector.snapshot(at(20))

        assertFalse("a bus that far off the route is not travelling it", ride.hasRouteValidProgress)
    }

    @Test
    fun aRideRoundAHairpinCountsItsStopsDown() {
        // Stop 6 lies east of the foot of the return leg.
        for (byPhone in listOf(false, true)) {
            val detector = TripRideDetector(HAIRPIN, pathId = 0, boardingStopId = 1, destinationStopId = 6)
            detector.onBusReports(listOf(report(0, x = 0.0, y = 0.0)))
            if (byPhone) {
                detector.onUserLocation(fix(0, x = 0.0, y = 0.0))
            }
            detector.confirmBoardedByUser(at(0))
            assertTrue(detector.snapshot(at(0)).hasBoarded)

            val remaining = listOf(100L to 1, 104L to 2, 154L to 3, 204L to 4).map { (seconds, stop) ->
                val (x, y) = HAIRPIN_POINTS[stop]
                if (byPhone) {
                    detector.onUserLocation(fix(seconds, x, y))
                } else {
                    detector.onBusReports(listOf(report(seconds, x, y)))
                }
                detector.snapshot(at(seconds)).remainingStops
            }

            assertEquals(
                if (byPhone) "by the rider's own fixes" else "by the bus's reports",
                listOf<Int?>(4, 3, 2, 1),
                remaining,
            )
        }
    }

    private fun report(seconds: Long, x: Double, y: Double) = RideBusReport(
        vehicleId = "BUS",
        pathId = 0,
        latitude = lat(y),
        longitude = lon(x),
        gpsTimeMs = at(seconds),
        receivedAtMs = at(seconds),
    )

    private fun fix(seconds: Long, x: Double, y: Double) = RideGeoPoint(
        latitude = lat(y),
        longitude = lon(x),
        timestampMs = at(seconds),
        accuracyMeters = 10f,
        speedMetersPerSecond = 5f,
    )

    private fun at(seconds: Long) = BASE_MS + seconds * 1_000L

    private companion object {
        const val BASE_MS = 1_700_000_000_000L
        const val ORIGIN_LAT = 24.1
        const val ORIGIN_LON = 120.6
        const val METERS_PER_DEGREE = 6_371_000.0 * PI / 180.0

        val HAIRPIN_POINTS = listOf(
            0.0 to 0.0, 0.0 to 1_000.0, 40.0 to 1_000.0, 40.0 to 500.0, 40.0 to 0.0, 500.0 to 0.0,
        )
        val HAIRPIN = routeOf(*HAIRPIN_POINTS.toTypedArray())

        fun lat(northMeters: Double) = ORIGIN_LAT + northMeters / METERS_PER_DEGREE

        fun lon(eastMeters: Double) =
            ORIGIN_LON + eastMeters / (METERS_PER_DEGREE * cos(ORIGIN_LAT * PI / 180.0))

        fun routeOf(vararg points: Pair<Double, Double>): List<TrackingStop> =
            points.mapIndexed { index, (east, north) ->
                TrackingStop(
                    stopId = index + 1,
                    stopName = "s$index",
                    sequence = index,
                    lat = lat(north),
                    lon = lon(east),
                )
            }
    }
}
