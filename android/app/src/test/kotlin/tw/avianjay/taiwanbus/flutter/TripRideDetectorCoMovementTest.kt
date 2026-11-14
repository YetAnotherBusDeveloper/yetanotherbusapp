package tw.avianjay.taiwanbus.flutter

import kotlin.math.PI
import kotlin.math.cos
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Which vehicles may confirm a ride.
 *
 * The position feed lists every vehicle of the route: this direction's, the
 * other direction's, and ones parked or deadheading beside it. All of them
 * project to some position along the trip's stops, so a vehicle that merely
 * moves in step with the phone used to be taken for the rider's bus whatever
 * direction it reported and however far off the route it was.
 *
 * The route is a straight northbound line of five stops 500 m apart. Every ride
 * here covers 300 m, short of what the rider's own progress would need to count
 * by itself, so the vehicle is the only thing that can confirm it.
 */
class TripRideDetectorCoMovementTest {
    @Test
    fun ridingABusOfThisDirectionIsDetected() {
        val ride = rideAlongside { seconds -> report(seconds, along = 5.0 * seconds) }

        assertTrue("the scenario has to be one a real bus would confirm", ride.hasBoarded)
        assertEquals(BoardingEvidence.BUS_CO_MOVEMENT, ride.evidence)
        assertEquals(BUS, ride.trackedVehicleId)
    }

    @Test
    fun aBusOfTheOtherDirectionIsNotTheRidersBus() {
        val ride = rideAlongside { seconds -> report(seconds, along = 5.0 * seconds, pathId = 1) }

        assertFalse("a bus going the other way cannot be the one the rider is on", ride.hasBoarded)
        assertEquals(BoardingEvidence.NONE, ride.evidence)
        assertNull(ride.trackedVehicleId)
    }

    @Test
    fun aVehicleOffTheRouteIsNotTheRidersBus() {
        // 350 m to the side: deadheading down a parallel street.
        val ride = rideAlongside { seconds ->
            report(seconds, along = 5.0 * seconds, offsetMeters = 350.0)
        }

        assertFalse("a vehicle that is not on the route cannot be the rider's bus", ride.hasBoarded)
        assertNull(ride.trackedVehicleId)
    }

    @Test
    fun reportsEitherSideOfAStretchOnTheOtherDirectionDoNotAddUp() {
        // On this direction, then one report on the other, then back: too few
        // reports on either side to confirm anything, and the two sides are not
        // one journey.
        val ride = rideAlongside { seconds ->
            report(seconds, along = 5.0 * seconds, pathId = if (seconds == 40L) 1 else 0)
        }

        assertFalse(ride.hasBoarded)
    }

    @Test
    fun aVehicleParkedBesideTheRouteIsNotPickedAsTheBusBeingRidden() {
        val detector = newDetector()
        // The parked vehicle is level with the rider; the bus they are on was
        // last reported 400 m back, as the feed's delay makes usual.
        detector.onBusReports(
            listOf(
                report(0, along = 1_000.0, offsetMeters = 350.0, vehicleId = "PARKED"),
                report(0, along = 600.0),
            ),
        )
        detector.onUserLocation(fix(0, along = 1_000.0))
        detector.confirmBoardedByUser(at(0))

        assertEquals(BUS, detector.snapshot(at(0)).trackedVehicleId)
    }

    @Test
    fun anInvalidReportCannotDriveAnAlreadyConfirmedRide() {
        for ((pathId, offsetMeters) in listOf(1 to 0.0, 0 to 350.0)) {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0)))
            detector.confirmBoardedByUser(at(0))
            assertEquals(BUS, detector.snapshot(at(0)).trackedVehicleId)

            detector.onBusReports(listOf(report(30, along = 1_500.0, pathId = pathId, offsetMeters = offsetMeters)))
            val ride = detector.snapshot(at(30))
            assertTrue(ride.hasBoarded)
            assertEquals("keep the ride's identity without trusting the invalid position", BUS, ride.trackedVehicleId)
            assertEquals(-1, ride.progressStopIndex)
            assertFalse(ride.hasRouteValidProgress)

            detector.onBusReports(listOf(report(60, along = 1_600.0)))
            val recovered = detector.snapshot(at(60))
            assertEquals(BUS, recovered.trackedVehicleId)
            assertEquals(3, recovered.progressStopIndex)
            assertTrue(recovered.hasRouteValidProgress)
        }
    }

    @Test
    fun aVehicleFeedOutageDoesNotLoseTheRideOrSwitchToAnotherBus() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(0))
        detector.onBusReports(listOf(report(200, along = 50.0, vehicleId = "OTHER")))

        val outage = detector.snapshot(at(200))
        assertEquals(BUS, outage.trackedVehicleId)
        assertEquals(-1, outage.progressStopIndex)
        assertFalse(outage.hasRouteValidProgress)

        detector.onBusReports(listOf(report(201, along = 1_600.0)))
        val recovered = detector.snapshot(at(201))
        assertEquals(BUS, recovered.trackedVehicleId)
        assertEquals(3, recovered.progressStopIndex)
        assertTrue(recovered.hasRouteValidProgress)
    }

    @Test
    fun aStalePhoneFixDoesNotPreventConfirmationFromPickingTheBus() {
        val detector = newDetector()
        detector.onUserLocation(fix(-300, along = 0.0))
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(0))

        val ride = detector.snapshot(at(0))
        assertFalse(ride.hasUsableLocation)
        assertEquals(BUS, ride.trackedVehicleId)
    }

    @Test
    fun anOffRouteReportCannotAnnounceADeparture() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        assertEquals(0L, detector.snapshot(at(0)).boardingCheckId)
        detector.onBusReports(listOf(report(30, along = 600.0, offsetMeters = 350.0)))

        assertEquals(
            "leaving the route is not evidence of departing the boarding stop",
            0L,
            detector.snapshot(at(30)).boardingCheckId,
        )
    }

    /** The rider travels 300 m up the route in a minute, beside whatever [vehicle] reports. */
    private fun rideAlongside(vehicle: (Long) -> RideBusReport): RideSnapshot {
        val detector = newDetector()
        var snapshot = RideSnapshot()
        for (seconds in 0L..60L step 20L) {
            detector.onBusReports(listOf(vehicle(seconds)))
            detector.onUserLocation(fix(seconds, along = 5.0 * seconds))
            snapshot = detector.snapshot(at(seconds))
        }
        return snapshot
    }

    private fun newDetector() = TripRideDetector(
        stops = (0..4).map { index ->
            val (lat, lon) = point(index * 500.0, 0.0)
            TrackingStop(stopId = 900 + index, stopName = "stop-$index", sequence = index, lat = lat, lon = lon)
        },
        pathId = 0,
        boardingStopId = 900,
        destinationStopId = 904,
    )

    private fun fix(seconds: Long, along: Double): RideGeoPoint {
        val (lat, lon) = point(along, 0.0)
        return RideGeoPoint(lat, lon, at(seconds), accuracyMeters = 12f, speedMetersPerSecond = 5f)
    }

    private fun report(
        seconds: Long,
        along: Double,
        pathId: Int = 0,
        offsetMeters: Double = 0.0,
        vehicleId: String = BUS,
    ): RideBusReport {
        val (lat, lon) = point(along, offsetMeters)
        return RideBusReport(vehicleId, pathId, lat, lon, gpsTimeMs = at(seconds), receivedAtMs = at(seconds))
    }

    private fun at(seconds: Long): Long = 1_700_000_000_000L + seconds * 1_000L

    /** [offsetMeters] is measured east of the route, which runs due north. */
    private fun point(alongMeters: Double, offsetMeters: Double): Pair<Double, Double> {
        val metersPerDegreeLat = 6_371_000.0 * PI / 180.0
        return 24.0 + alongMeters / metersPerDegreeLat to
            120.5 + offsetMeters / (metersPerDegreeLat * cos(24.0 * PI / 180.0))
    }

    private companion object {
        const val BUS = "AAA-001"
    }
}
