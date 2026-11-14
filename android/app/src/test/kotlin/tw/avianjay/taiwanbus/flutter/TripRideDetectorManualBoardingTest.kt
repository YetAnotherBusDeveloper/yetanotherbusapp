package tw.avianjay.taiwanbus.flutter

import kotlin.math.PI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Confirming a ride says nothing about which of the route's vehicles it is. */
class TripRideDetectorManualBoardingTest {
    @Test
    fun manualConfirmationDoesNotChooseAnEarlierBusSeveralStopsAhead() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 2_500.0, id = "AHEAD-ONLY")))
        detector.confirmBoardedByUser(at(0))

        assertUnidentified(detector.snapshot(at(0)))
    }

    @Test
    fun anUnknownRideWaitsForItsActualBoardingBus() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 2_500.0, id = "EARLIER")))
        detector.confirmBoardedByUser(at(0))
        assertUnidentified(detector.snapshot(at(0)))

        // The feed runs behind: the fix the rider's bus made at the stop, just
        // before they confirmed, only reaches the app now.
        detector.onBusReports(listOf(
            report(20, along = 2_500.0, id = "EARLIER"),
            report(-5, along = 0.0).copy(receivedAtMs = at(20)),
        ))
        assertEquals(BUS, detector.snapshot(at(20)).trackedVehicleId)

        // Identification is bounded; travel on the identified vehicle is not.
        detector.onBusReports(listOf(report(180, along = 2_000.0)))
        val ride = detector.snapshot(at(180))
        assertEquals(BUS, ride.trackedVehicleId)
        assertEquals(1, ride.passedDestinationByStops)
        assertTrue(ride.hasRouteValidProgress)
    }

    @Test
    fun aNearbyVehicleNeedsAnActualAtStopObservation() {
        for (along in listOf(100.0, 200.0)) {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = along)))
            detector.confirmBoardedByUser(at(0))

            assertUnidentified(detector.snapshot(at(0)))
        }
    }

    @Test
    fun aVehicleBeforeTheFirstStopIsNotAtTheBoardingStop() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = -200.0)))
        detector.confirmBoardedByUser(at(0))

        assertUnidentified(detector.snapshot(at(0)))
    }

    @Test
    fun aVehicleBesideTheStopIsNotAnAtStopObservation() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0).copy(longitude = 120.6015)))
        detector.confirmBoardedByUser(at(0))

        assertUnidentified(detector.snapshot(at(0)))
    }

    @Test
    fun aRecentBoundedDepartureCanBeIdentified() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0), report(20, along = 200.0)))
        detector.confirmBoardedByUser(at(20))

        assertEquals(BUS, detector.snapshot(at(20)).trackedVehicleId)
    }

    @Test
    fun aLaterBusCallingAtTheStopIsNotTheConfirmedRide() {
        // The rider's own bus has no position feed. Whatever pulls in after
        // they said they were on board is the next bus.
        for (arrivesAfterSeconds in listOf(1L, 20L, 60L, 110L)) {
            val detector = newDetector()
            detector.confirmBoardedByUser(at(0))
            assertUnidentified(detector.snapshot(at(0)))

            detector.onBusReports(listOf(report(arrivesAfterSeconds, along = 0.0, id = "LATER-BUS")))
            assertUnidentified(detector.snapshot(at(arrivesAfterSeconds)))

            // It runs on past the rider's destination; the ride is not it.
            detector.onBusReports(listOf(report(arrivesAfterSeconds + 60, along = 2_000.0, id = "LATER-BUS")))
            assertUnidentified(detector.snapshot(at(arrivesAfterSeconds + 60)))
        }
    }

    @Test
    fun aLaterBusIsNotTakenEvenAfterTheRidersOwnBusWasSeenLeaving() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(-10, along = 0.0)))
        detector.confirmBoardedByUser(at(0))
        assertEquals(BUS, detector.snapshot(at(0)).trackedVehicleId)

        detector.onBusReports(listOf(report(60, along = 600.0), report(60, along = 0.0, id = "LATER-BUS")))
        assertEquals(BUS, detector.snapshot(at(60)).trackedVehicleId)
    }

    @Test
    fun answeringTheQuestionAboutANamedBusFollowsThatBus() {
        // The question comes up 40 s after the bus has left, by which time it
        // is well down the road; "yes" is still about that bus.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0)))
        assertTrue(detector.snapshot(at(20)).boardingCheckId != 0L)
        detector.onBusReports(listOf(report(60, along = 700.0), report(60, along = 0.0, id = "OTHER")))
        assertTrue(detector.snapshot(at(60)).boardingPromptDue)
        detector.confirmBoardedByUser(at(70))

        val ride = detector.snapshot(at(70))
        assertEquals(BUS, ride.trackedVehicleId)
        assertEquals(1, ride.progressStopIndex)
        assertTrue(ride.hasRouteValidProgress)
    }

    @Test
    fun aQuestionThatHasLapsedNamesNoBus() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0)))
        assertTrue(detector.snapshot(at(20)).boardingCheckId != 0L)
        detector.onBusReports(listOf(report(330, along = 2_400.0)))
        // Not snapshotted in between, so the question was never retired.
        detector.confirmBoardedByUser(at(330))

        assertUnidentified(detector.snapshot(at(330)))
    }

    @Test
    fun aVehicleBackAfterALongSilenceDidNotJustLeaveTheStop() {
        for ((silenceSeconds, asked) in listOf(180L to true, 181L to false)) {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0)))
            assertEquals(0L, detector.snapshot(at(0)).boardingCheckId)
            detector.onBusReports(listOf(report(silenceSeconds, along = 2_400.0)))

            assertEquals(
                "a bus last seen at the stop $silenceSeconds s ago",
                asked,
                detector.snapshot(at(silenceSeconds)).boardingCheckId != 0L,
            )
        }
    }

    @Test
    fun aRidePickedBackUpDoesNotAdoptTheBusNowAtTheBoardingStop() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(-10, along = 0.0, id = "NEXT-BUS")))
        detector.resumeConfirmedRide()

        assertUnidentified(detector.snapshot(at(0)))
        detector.onBusReports(listOf(report(20, along = 100.0, id = "NEXT-BUS")))
        assertUnidentified(detector.snapshot(at(20)))

        // The rider's own position is what finds their bus again.
        detector.onBusReports(listOf(report(40, along = 1_400.0)))
        detector.onUserLocation(RideGeoPoint(latitude(1_500.0), 120.6, at(40), accuracyMeters = 10f))
        assertEquals(BUS, detector.snapshot(at(40)).trackedVehicleId)
    }

    @Test
    fun atStopEvidenceMustBeFromTheNinetySecondsBeforeConfirming() {
        for (seconds in listOf(90L, 91L)) {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0)))
            detector.snapshot(at(0))
            detector.onBusReports(listOf(report(seconds - 5, along = 100.0)))
            detector.confirmBoardedByUser(at(seconds))

            assertEquals(BUS.takeIf { seconds == 90L }, detector.snapshot(at(seconds)).trackedVehicleId)
        }
    }

    @Test
    fun repeatingTheSameFeedFixDoesNotRefreshItsEvidence() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.onBusReports(listOf(report(0, along = 0.0).copy(receivedAtMs = at(100))))
        detector.confirmBoardedByUser(at(100))

        assertUnidentified(detector.snapshot(at(100)))
    }

    @Test
    fun lateIdentificationExpiresAndRepeatedConfirmationDoesNotRearmIt() {
        for (seconds in listOf(120L, 121L)) {
            val detector = newDetector()
            detector.confirmBoardedByUser(at(0))
            // Made at the stop before the rider confirmed, delivered late.
            detector.onBusReports(listOf(report(-10, along = 0.0).copy(receivedAtMs = at(seconds))))
            val expected = BUS.takeIf { seconds == 120L }
            assertEquals(expected, detector.snapshot(at(seconds)).trackedVehicleId)
            detector.confirmBoardedByUser(at(seconds + 1))

            assertEquals(expected, detector.snapshot(at(seconds + 1)).trackedVehicleId)
        }
    }

    @Test
    fun anInvalidStretchBreaksTheAtStopEvidence() {
        for ((pathId, longitude) in listOf(1 to 120.6, 0 to 120.61)) {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0)))
            detector.onBusReports(listOf(report(10, along = 100.0).copy(pathId = pathId, longitude = longitude)))
            detector.onBusReports(listOf(report(20, along = 200.0)))
            detector.confirmBoardedByUser(at(20))

            assertUnidentified(detector.snapshot(at(20)))
        }
    }

    @Test
    fun ambiguousNearbyVehiclesDoNotBecomeIdentifiedJustBecauseOneLeavesTheBound() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0), report(0, along = 0.0, id = "OTHER")))
        detector.confirmBoardedByUser(at(0))
        assertUnidentified(detector.snapshot(at(0)))
        detector.onBusReports(listOf(report(20, along = 500.0), report(20, along = 0.0, id = "OTHER")))

        assertUnidentified(detector.snapshot(at(20)))
        detector.onUserLocation(RideGeoPoint(latitude(500.0), 120.6, at(20), accuracyMeters = 10f))
        assertEquals(BUS, detector.snapshot(at(20)).trackedVehicleId)
    }

    @Test
    fun confirmingAnIdentifiedRideDoesNotSwitchToANearerVehicle() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(0))
        assertEquals(BUS, detector.snapshot(at(0)).trackedVehicleId)
        detector.onBusReports(listOf(report(60, along = 1_500.0), report(60, along = 0.0, id = "OTHER")))
        detector.confirmBoardedByUser(at(60))

        assertEquals(BUS, detector.snapshot(at(60)).trackedVehicleId)
    }

    @Test
    fun aValidNamedDepartureCanDisambiguateNearbyVehicles() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0), report(20, along = 0.0, id = "OTHER")))
        assertTrue(detector.snapshot(at(20)).boardingCheckId != 0L)
        detector.confirmBoardedByUser(at(20))

        assertEquals(BUS, detector.snapshot(at(20)).trackedVehicleId)
    }

    private fun assertUnidentified(ride: RideSnapshot) {
        assertTrue("the manual action still confirms that the rider boarded", ride.hasBoarded)
        assertEquals(BoardingEvidence.USER_CONFIRMED, ride.evidence)
        assertNull("confirming a ride does not identify an unrelated vehicle", ride.trackedVehicleId)
        assertEquals(-1, ride.progressStopIndex)
        assertNull(ride.passedDestinationByStops)
        assertFalse(ride.hasRouteValidProgress)
    }

    private fun newDetector() = TripRideDetector(
        stops = (0..5).map { index ->
            TrackingStop(index + 1, "stop-$index", index, latitude(index * 500.0), 120.6)
        },
        pathId = 0, boardingStopId = 1, destinationStopId = 4,
    )

    private fun report(seconds: Long, along: Double, id: String = BUS) = RideBusReport(
        id, 0, latitude(along), 120.6, gpsTimeMs = at(seconds), receivedAtMs = at(seconds),
    )

    private fun latitude(meters: Double) = 24.1 + meters / (6_371_000.0 * PI / 180.0)

    private fun at(seconds: Long) = 1_700_000_000_000L + seconds * 1_000L

    private companion object {
        const val BUS = "ACTUAL"
    }
}
