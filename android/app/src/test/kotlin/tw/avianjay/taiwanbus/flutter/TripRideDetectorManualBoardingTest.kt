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
    fun aBusStillAtTheStopWhenTheRiderConfirmsIsTheirs() {
        // Its next report, already made but not yet delivered, shows it moving
        // off with them on board.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(15))
        assertEquals(BUS, detector.snapshot(at(15)).trackedVehicleId)

        detector.onBusReports(listOf(report(40, along = 300.0)))
        assertEquals(BUS, detector.snapshot(at(40)).trackedVehicleId)
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
        detector.onBusReports(listOf(report(60, along = 700.0)))
        val question = detector.snapshot(at(60))
        assertTrue(question.boardingPromptDue)
        detector.confirmBoardedByUser(at(70), answeredCheckId = question.boardingCheckId)

        val ride = detector.snapshot(at(70))
        assertEquals(BUS, ride.trackedVehicleId)
        assertEquals(1, ride.progressStopIndex)
        assertTrue(ride.hasRouteValidProgress)
    }

    @Test
    fun confirmingUnpromptedDoesNotAdoptABusAboutToBeAskedAbout() {
        // Bus A leaves and a question about it is pending, but is not shown for
        // another 40 s. Meanwhile the rider gets on bus B, which has no
        // position feed, and says so with the button that is always there.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        val pending = detector.snapshot(at(20))
        assertTrue(pending.boardingCheckId != 0L)
        assertFalse("the rider has not been asked anything yet", pending.boardingPromptDue)
        detector.confirmBoardedByUser(at(30))

        assertUnidentified(detector.snapshot(at(30)))
        // A carries on past the rider's destination; the ride is not on it.
        detector.onBusReports(listOf(report(150, along = 2_000.0, id = "BUS-A")))
        assertUnidentified(detector.snapshot(at(150)))
    }

    @Test
    fun confirmingUnpromptedWhileAQuestionIsShowingIsStillNotAnAnswerToIt() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        detector.snapshot(at(20))
        detector.onBusReports(listOf(report(60, along = 700.0, id = "BUS-A")))
        assertTrue(detector.snapshot(at(60)).boardingPromptDue)
        detector.confirmBoardedByUser(at(70))

        assertUnidentified(detector.snapshot(at(70)))
    }

    @Test
    fun anAnswerToAQuestionSinceReplacedNamesNoBus() {
        // The question about bus A has been on screen for a while when bus B
        // leaves, and the rider is to be asked afresh. Until that shows, the
        // notification they can see and answer is still the old one.
        for (boarded in listOf(true, false)) {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
            detector.snapshot(at(0))
            detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
            val aboutA = detector.snapshot(at(20)).boardingCheckId
            detector.onBusReports(listOf(report(100, along = 0.0, id = "BUS-B")))
            detector.snapshot(at(100))
            detector.onBusReports(listOf(report(120, along = 150.0, id = "BUS-B")))
            val afresh = detector.snapshot(at(120)).boardingCheckId
            assertTrue("B leaving this long after must be asked about afresh", afresh != 0L && afresh != aboutA)

            if (boarded) {
                detector.confirmBoardedByUser(at(125), answeredCheckId = aboutA)
                assertUnidentified(detector.snapshot(at(125)))
            } else {
                detector.declineBoarding(at(125), answeredCheckId = aboutA)
                val ride = detector.snapshot(at(165))
                assertEquals("the new question still stands", afresh, ride.boardingCheckId)
                assertTrue(ride.boardingPromptDue)

                // It is about both buses: A left unanswered for, not long ago.
                detector.confirmBoardedByUser(at(170), answeredCheckId = afresh)
                assertUnidentified(detector.snapshot(at(170)))
            }
        }
    }

    @Test
    fun aQuestionThatHasLapsedNamesNoBus() {
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0)))
        val question = detector.snapshot(at(20)).boardingCheckId
        assertTrue(question != 0L)
        // Another bus is standing at the stop by now.
        detector.onBusReports(listOf(report(330, along = 2_400.0), report(325, along = 0.0, id = "OTHER")))
        // Not snapshotted in between, so the question was never retired.
        detector.confirmBoardedByUser(at(330), answeredCheckId = question)

        // "Yes" was to a question about a bus long gone, not about this one.
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
    fun twoBusesLeavingCloseTogetherAreNotOneDeparture() {
        // A and B stand at the stop together. A leaves, and B forty seconds
        // behind it, before the question about A has even been shown. The one
        // question the rider then sees is about both.
        val detector = newDetector()
        detector.reportBoth(0, a = 0.0, b = 0.0)
        detector.snapshot(at(0))
        detector.reportBoth(20, a = 150.0, b = 0.0)
        val asked = detector.snapshot(at(20)).boardingCheckId
        assertTrue("A leaving must raise the question", asked != 0L)
        detector.reportBoth(60, a = 600.0, b = 150.0)
        val question = detector.snapshot(at(60))
        assertEquals("B leaving so soon after is asked about in the same breath", asked, question.boardingCheckId)
        assertTrue(question.boardingPromptDue)
        detector.reportBoth(80, a = 900.0, b = 400.0)
        detector.snapshot(at(80))

        // The rider got on B. "Yes" is as true of A, so it names neither.
        detector.confirmBoardedByUser(at(85), answeredCheckId = asked)
        assertUnidentified(detector.snapshot(at(85)))

        // A runs on past the rider's stop while B, with the rider, is short of it.
        detector.reportBoth(200, a = 2_400.0, b = 1_200.0)
        assertUnidentified(detector.snapshot(at(200)))
    }

    @Test
    fun aSecondBusAlreadyReportedGoneCountsBeforeAnySnapshotIsTaken() {
        // The report that shows B gone as well arrives, and the rider answers
        // before the detector has been asked to look again.
        for (boarded in listOf(true, false)) {
            val detector = newDetector()
            detector.reportBoth(0, a = 0.0, b = 0.0)
            detector.snapshot(at(0))
            detector.reportBoth(20, a = 150.0, b = 0.0)
            val asked = detector.snapshot(at(20)).boardingCheckId
            assertTrue(asked != 0L)
            detector.reportBoth(60, a = 600.0, b = 400.0)

            if (boarded) {
                detector.confirmBoardedByUser(at(61), answeredCheckId = asked)
                assertUnidentified(detector.snapshot(at(61)))
            } else {
                detector.declineBoarding(at(61), answeredCheckId = asked)
                assertEquals(
                    "still waiting means on neither, so B is not asked about next",
                    0L,
                    detector.snapshot(at(61)).boardingCheckId,
                )
            }
        }
    }

    @Test
    fun aRiderNoLongerAtTheStopIsNotAskedAfresh() {
        // At the stop when A leaves; a few minutes on, some 350 m off to the
        // side — not gone, but not where a bus is boarded — when B does.
        val detector = newDetector()
        detector.onUserLocation(RideGeoPoint(latitude(0.0), 120.6, at(0), accuracyMeters = 10f))
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        val asked = detector.snapshot(at(20)).boardingCheckId
        assertTrue(asked != 0L)
        for (seconds in 60L..200L step 20L) {
            detector.onUserLocation(RideGeoPoint(latitude(0.0), 120.6034, at(seconds), accuracyMeters = 10f))
        }
        detector.onBusReports(listOf(report(180, along = 0.0, id = "BUS-B")))
        detector.snapshot(at(180))
        detector.onBusReports(listOf(report(200, along = 150.0, id = "BUS-B")))
        val ride = detector.snapshot(at(200))

        assertFalse(ride.hasBoarded)
        assertEquals("B leaving is not a reason to ask someone who is not at the stop", asked, ride.boardingCheckId)
    }

    @Test
    fun aBusSeenLeavingTwiceIsOneDeparture() {
        // A fix that wanders back to the stop makes the bus "leave" again.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0)))
        val asked = detector.snapshot(at(20)).boardingCheckId
        assertTrue(asked != 0L)
        detector.onBusReports(listOf(report(40, along = 30.0)))
        detector.snapshot(at(40))
        detector.onBusReports(listOf(report(60, along = 400.0)))
        assertTrue(detector.snapshot(at(60)).boardingPromptDue)
        detector.confirmBoardedByUser(at(70), answeredCheckId = asked)

        assertEquals(BUS, detector.snapshot(at(70)).trackedVehicleId)
    }

    @Test
    fun aBusNotHeardFromForThreeMinutesDoesNotLeaveTheAnswerOpen() {
        // B was last reported at the boarding stop, 500 m along, and then
        // nothing: a bus the feed can no longer place is not one to weigh.
        for ((silentForSeconds, namesTheBus) in listOf(180L to false, 181L to true)) {
            val detector = newDetector(boardingStopId = 2)
            detector.onBusReports(listOf(report(70 - silentForSeconds, along = 500.0, id = "BUS-B")))
            detector.onBusReports(listOf(report(0, along = 500.0, id = "BUS-A")))
            detector.snapshot(at(0))
            detector.onBusReports(listOf(report(20, along = 650.0, id = "BUS-A")))
            val asked = detector.snapshot(at(20)).boardingCheckId
            assertTrue(asked != 0L)
            detector.onBusReports(listOf(report(60, along = 1_200.0, id = "BUS-A")))
            detector.snapshot(at(60))
            detector.confirmBoardedByUser(at(70), answeredCheckId = asked)

            assertEquals(
                "B last heard from $silentForSeconds s before the answer",
                "BUS-A".takeIf { namesTheBus },
                detector.snapshot(at(70)).trackedVehicleId,
            )
        }
    }

    @Test
    fun aBusTheRiderCouldHaveBoardedSinceLeavesTheAnswerOpen() {
        // The boarding stop is the second one, 500 m along. A has left it and
        // the rider is asked; "yes" comes with B at [bAlong].
        fun answerWithBAt(bAlong: Double): RideSnapshot {
            val detector = newDetector(boardingStopId = 2)
            detector.onBusReports(listOf(report(0, along = 500.0, id = "BUS-A")))
            detector.snapshot(at(0))
            detector.onBusReports(listOf(report(20, along = 650.0, id = "BUS-A")))
            val asked = detector.snapshot(at(20)).boardingCheckId
            assertTrue(asked != 0L)
            detector.reportBoth(60, a = 1_200.0, b = bAlong)
            assertTrue(detector.snapshot(at(60)).boardingPromptDue)
            detector.confirmBoardedByUser(at(70), answeredCheckId = asked)
            return detector.snapshot(at(70))
        }
        // Standing at the stop; near enough to have pulled in since it last
        // reported; just gone from the stop without having been seen arriving.
        for (bAlong in listOf(500.0, 250.0, 700.0)) {
            assertUnidentified(answerWithBAt(bAlong))
        }
        // Too far short of the stop to have reached it, or long past it.
        for (bAlong in listOf(150.0, 800.0)) {
            assertEquals("BUS-A", answerWithBAt(bAlong).trackedVehicleId)
        }
    }

    @Test
    fun unpromptedTheBusAtTheStopIsNotAdoptedWhileOneThatLeftIsUnanswered() {
        // A has left and is waiting to be asked about. B pulls in. The rider
        // says they are on board without having been asked: on A, already down
        // the road, or on B — the words are the same.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        assertTrue(detector.snapshot(at(20)).boardingCheckId != 0L)
        detector.reportBoth(40, a = 450.0, b = 0.0)
        assertFalse("nothing has been asked yet", detector.snapshot(at(40)).boardingPromptDue)
        detector.confirmBoardedByUser(at(45))

        assertUnidentified(detector.snapshot(at(45)))
        // Nor does B become the ride for staying while A draws away.
        detector.reportBoth(60, a = 700.0, b = 0.0)
        assertUnidentified(detector.snapshot(at(60)))
        detector.reportBoth(80, a = 950.0, b = 150.0)
        assertUnidentified(detector.snapshot(at(80)))
    }

    @Test
    fun unpromptedASecondBusNearTheStopLeavesTheRideUnidentified() {
        // A stands at the boarding stop, 500 m along; B is at [bAlong].
        fun confirmWithBAt(bAlong: Double): TripRideDetector {
            val detector = newDetector(boardingStopId = 2)
            detector.reportBoth(0, a = 500.0, b = bAlong)
            detector.confirmBoardedByUser(at(5))
            return detector
        }
        // Coming up to the stop, or just pulling away from it.
        for (bAlong in listOf(250.0, 600.0)) {
            val detector = confirmWithBAt(bAlong)
            assertUnidentified(detector.snapshot(at(5)))
            // B moving on does not settle which of the two it was.
            detector.reportBoth(30, a = 500.0, b = bAlong + 400.0)
            assertUnidentified(detector.snapshot(at(30)))
        }
        // Too far back to have reached the stop.
        assertEquals("BUS-A", confirmWithBAt(150.0).snapshot(at(5)).trackedVehicleId)
    }

    @Test
    fun unpromptedABusAlreadyTurnedDownDoesNotLeaveTheRideUnidentified() {
        // A left and the rider said "not yet". It is held up just past the stop
        // when B pulls in; the rider gets on B and says so.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        val asked = detector.snapshot(at(20)).boardingCheckId
        detector.onBusReports(listOf(report(60, along = 200.0, id = "BUS-A")))
        assertTrue(detector.snapshot(at(60)).boardingPromptDue)
        detector.declineBoarding(at(65), answeredCheckId = asked)
        detector.reportBoth(80, a = 210.0, b = 0.0)
        detector.snapshot(at(80))
        detector.confirmBoardedByUser(at(85))

        assertEquals("BUS-B", detector.snapshot(at(85)).trackedVehicleId)
        // And its report at the stop may as well arrive after the rider spoke.
        val late = newDetector()
        late.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        late.snapshot(at(0))
        late.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        val askedLate = late.snapshot(at(20)).boardingCheckId
        late.onBusReports(listOf(report(60, along = 200.0, id = "BUS-A")))
        late.snapshot(at(60))
        late.declineBoarding(at(65), answeredCheckId = askedLate)
        late.confirmBoardedByUser(at(85))
        assertUnidentified(late.snapshot(at(85)))
        late.onBusReports(
            listOf(
                report(100, along = 210.0, id = "BUS-A"),
                report(80, along = 0.0, id = "BUS-B").copy(receivedAtMs = at(100)),
            ),
        )
        assertEquals("BUS-B", late.snapshot(at(100)).trackedVehicleId)
    }

    @Test
    fun aRolloverBesideABusSeenLeavingIsThatBusOnlyWhenTheFeedSaysSo() {
        // A is seen at the stop and leaving. Within the minute the ETA rolls
        // over. [atStop] is the bus the stop feed placed there, if it said.
        fun answer(atStop: String?, aSecondRollover: Boolean = false): RideSnapshot {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0)))
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), arrivingVehicleIds = listOfNotNull(atStop))
            detector.snapshot(at(0))
            detector.onBusReports(listOf(report(20, along = 150.0)))
            val asked = detector.snapshot(at(20)).boardingCheckId
            assertTrue(asked != 0L)
            detector.onBoardingStopEta(600, arriving = false, nowMs = at(50))
            if (aSecondRollover) {
                detector.onBoardingStopEta(0, arriving = true, nowMs = at(60), arrivingVehicleIds = listOfNotNull(atStop))
                detector.onBoardingStopEta(600, arriving = false, nowMs = at(80))
            }
            detector.onBusReports(listOf(report(80, along = 900.0)))
            val ride = detector.snapshot(at(84))
            assertEquals("the rollover is not asked about separately", asked, ride.boardingCheckId)
            detector.confirmBoardedByUser(at(85), answeredCheckId = asked)
            return detector.snapshot(at(85))
        }
        // The feed named the bus at the stop: the rollover is A leaving.
        assertEquals(BUS, answer(atStop = BUS).trackedVehicleId)
        assertEquals(BUS, answer(atStop = BUS, aSecondRollover = true).trackedVehicleId)
        // It named another: B, with no position feed, left as well.
        assertUnidentified(answer(atStop = "BUS-B"))
        // It named none. The rider may have boarded a B the app never saw.
        assertUnidentified(answer(atStop = null))
        assertUnidentified(answer(atStop = null, aSecondRollover = true))
    }

    @Test
    fun aPlateNoLongerAloneAtTheStopDoesNotNameTheRollover() {
        // No phone fix and no position feed. The stop feed places A at the
        // stop, then [later], and then the ETA rolls over.
        fun answer(later: List<String>): RideSnapshot {
            val detector = newDetector()
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), arrivingVehicleIds = listOf("BUS-A"))
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(20), arrivingVehicleIds = later)
            detector.onBoardingStopEta(600, arriving = false, nowMs = at(40))
            val asked = detector.snapshot(at(85))
            assertTrue(asked.boardingPromptDue)
            detector.confirmBoardedByUser(at(90), answeredCheckId = asked.boardingCheckId)
            return detector.snapshot(at(90))
        }
        // A and B together, then one of them leaves: the rider may be on B.
        assertUnidentified(answer(listOf("BUS-A", "BUS-B")))
        // B alone: A went unreported, and the rider may be on A.
        assertUnidentified(answer(listOf("BUS-B")))
        // Still A, or an update that carries no plate at all.
        assertEquals("BUS-A", answer(listOf("BUS-A")).trackedVehicleId)
        assertEquals("BUS-A", answer(emptyList()).trackedVehicleId)
    }

    @Test
    fun theNextArrivalStartsWithNoPlatesFromTheLast() {
        val detector = newDetector()
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), arrivingVehicleIds = listOf("BUS-A"))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        val first = detector.snapshot(at(65))
        detector.declineBoarding(at(70), answeredCheckId = first.boardingCheckId)
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(200), arrivingVehicleIds = listOf("BUS-B"))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(220))
        val second = detector.snapshot(at(265))
        assertTrue(second.boardingPromptDue)
        detector.confirmBoardedByUser(at(270), answeredCheckId = second.boardingCheckId)

        assertEquals("BUS-B", detector.snapshot(at(270)).trackedVehicleId)
    }

    @Test
    fun aBusSeenLeavingBesideAnUnnamedRolloverIsNotNamedByTheAnswer() {
        // The other order: the rollover first, then the position feed.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        detector.snapshot(at(0))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(15))
        val asked = detector.snapshot(at(15)).boardingCheckId
        assertTrue(asked != 0L)
        detector.onBusReports(listOf(report(10, along = 150.0).copy(receivedAtMs = at(30))))
        detector.snapshot(at(30))
        detector.onBusReports(listOf(report(60, along = 800.0)))
        assertEquals(asked, detector.snapshot(at(60)).boardingCheckId)
        detector.confirmBoardedByUser(at(65), answeredCheckId = asked)

        assertUnidentified(detector.snapshot(at(65)))
    }

    @Test
    fun eachDeclinedBusIsCaughtUpWithByTheEtaOnce() {
        // Two buses with no position feed, a "not yet" between them.
        val etaOnly = newDetector()
        etaOnly.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        etaOnly.onBoardingStopEta(600, arriving = false, nowMs = at(30))
        val first = etaOnly.snapshot(at(75))
        assertTrue(first.boardingPromptDue)
        etaOnly.declineBoarding(at(80), answeredCheckId = first.boardingCheckId)
        etaOnly.onBoardingStopEta(0, arriving = true, nowMs = at(90))
        etaOnly.onBoardingStopEta(600, arriving = false, nowMs = at(110))
        assertTrue("the second bus is asked about", etaOnly.snapshot(at(110)).boardingCheckId != 0L)

        // A bus seen leaving and declined: its rollover is swallowed, the next is not.
        val seen = newDetector()
        seen.onBusReports(listOf(report(0, along = 0.0)))
        seen.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        seen.snapshot(at(0))
        seen.onBusReports(listOf(report(20, along = 150.0)))
        val asked = seen.snapshot(at(20)).boardingCheckId
        seen.onBusReports(listOf(report(60, along = 700.0)))
        assertTrue(seen.snapshot(at(60)).boardingPromptDue)
        seen.declineBoarding(at(65), answeredCheckId = asked)
        seen.onBoardingStopEta(600, arriving = false, nowMs = at(70))
        assertEquals("A's own rollover", 0L, seen.snapshot(at(70)).boardingCheckId)
        seen.onBoardingStopEta(0, arriving = true, nowMs = at(80))
        seen.onBoardingStopEta(600, arriving = false, nowMs = at(100))
        assertTrue("the next bus's rollover", seen.snapshot(at(100)).boardingCheckId != 0L)
    }

    @Test
    fun aBusStillAtTheStopAfterADeclinedRolloverIsTheNextBus() {
        for (stillThereAfterwards in listOf(false, true)) {
            val detector = newDetector()
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0))
            detector.onBoardingStopEta(600, arriving = false, nowMs = at(30))
            val first = detector.snapshot(at(75))
            assertTrue(first.boardingPromptDue)
            detector.declineBoarding(at(80), answeredCheckId = first.boardingCheckId)
            // The position feed, late: at the stop either before the rollover
            // (the same bus) or after it (the one behind).
            val atStopAt = if (stillThereAfterwards) 60L else 10L
            detector.onBusReports(listOf(report(atStopAt, along = 0.0).copy(receivedAtMs = at(85))))
            detector.snapshot(at(85))
            detector.onBusReports(listOf(report(95, along = 150.0)))

            assertEquals(stillThereAfterwards, detector.snapshot(at(100)).boardingCheckId != 0L)
        }
    }

    @Test
    fun notYetSetsAsideEveryBusThatHasLeft() {
        val detector = newDetector()
        detector.reportBoth(0, a = 0.0, b = 0.0)
        detector.snapshot(at(0))
        detector.reportBoth(20, a = 150.0, b = 0.0)
        val asked = detector.snapshot(at(20)).boardingCheckId
        detector.reportBoth(60, a = 600.0, b = 150.0)
        assertTrue(detector.snapshot(at(60)).boardingPromptDue)
        // Still waiting: on neither.
        detector.declineBoarding(at(70), answeredCheckId = asked)
        assertEquals(0L, detector.snapshot(at(70)).boardingCheckId)

        // B is held up just past the stop when the next bus comes and goes.
        detector.onBusReports(listOf(report(100, along = 200.0, id = "BUS-B"), report(100, along = 0.0)))
        detector.snapshot(at(100))
        detector.onBusReports(listOf(report(120, along = 220.0, id = "BUS-B"), report(120, along = 150.0)))
        val next = detector.snapshot(at(120)).boardingCheckId
        assertTrue("the next bus is asked about in its turn", next != 0L)
        detector.onBusReports(listOf(report(160, along = 230.0, id = "BUS-B"), report(160, along = 700.0)))
        assertTrue(detector.snapshot(at(160)).boardingPromptDue)
        detector.confirmBoardedByUser(at(170), answeredCheckId = next)

        assertEquals(
            "B was answered for already, and does not make this answer doubtful",
            BUS,
            detector.snapshot(at(170)).trackedVehicleId,
        )
    }

    private fun assertUnidentified(ride: RideSnapshot) {
        assertTrue("the manual action still confirms that the rider boarded", ride.hasBoarded)
        assertEquals(BoardingEvidence.USER_CONFIRMED, ride.evidence)
        assertNull("confirming a ride does not identify an unrelated vehicle", ride.trackedVehicleId)
        assertEquals(-1, ride.progressStopIndex)
        assertNull(ride.passedDestinationByStops)
        assertFalse(ride.hasRouteValidProgress)
    }

    /** Six stops 500 m apart; the rider gets off at the fourth. */
    private fun newDetector(boardingStopId: Int = 1) = TripRideDetector(
        stops = (0..5).map { index ->
            TrackingStop(index + 1, "stop-$index", index, latitude(index * 500.0), 120.6)
        },
        pathId = 0, boardingStopId = boardingStopId, destinationStopId = 4,
    )

    /** Buses A and B, reported together. */
    private fun TripRideDetector.reportBoth(seconds: Long, a: Double, b: Double) =
        onBusReports(listOf(report(seconds, along = a, id = "BUS-A"), report(seconds, along = b, id = "BUS-B")))

    private fun report(seconds: Long, along: Double, id: String = BUS) = RideBusReport(
        id, 0, latitude(along), 120.6, gpsTimeMs = at(seconds), receivedAtMs = at(seconds),
    )

    private fun latitude(meters: Double) = 24.1 + meters / (6_371_000.0 * PI / 180.0)

    private fun at(seconds: Long) = 1_700_000_000_000L + seconds * 1_000L

    private companion object {
        const val BUS = "ACTUAL"
    }
}
