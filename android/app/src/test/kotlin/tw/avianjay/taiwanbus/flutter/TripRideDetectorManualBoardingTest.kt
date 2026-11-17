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
                // "Yes" to the question about A is not an answer to this one.
                assertFalse(detector.confirmBoardedByUser(at(125), answeredCheckId = aboutA))
                val ride = detector.snapshot(at(165))
                assertFalse(ride.hasBoarded)
                assertEquals("the new question still stands", afresh, ride.boardingCheckId)
                assertTrue(ride.boardingPromptDue)

                assertTrue(detector.confirmBoardedByUser(at(170), answeredCheckId = afresh))
                assertUnidentified(detector.snapshot(at(170)))
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
    fun yesToAQuestionSinceTurnedDownIsNotYesToTheNext() {
        // Asked about A, the rider says "not yet". The "yes" they had also
        // tapped on that question arrives later, with B's question standing.
        val detector = newDetector()
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = listOf(atTheStop("BUS-A")))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        val aboutA = detector.snapshot(at(65)).boardingCheckId
        assertTrue(aboutA != 0L)
        assertTrue(detector.declineBoarding(at(70), answeredCheckId = aboutA))

        // With nothing asked, it confirms nothing.
        assertFalse(detector.confirmBoardedByUser(at(75), answeredCheckId = aboutA))
        assertFalse(detector.snapshot(at(75)).hasBoarded)

        detector.onBoardingStopEta(0, arriving = true, nowMs = at(200), buses = listOf(atTheStop("BUS-B")))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(220))
        val aboutB = detector.snapshot(at(265))
        assertTrue(aboutB.boardingPromptDue)
        assertFalse(detector.confirmBoardedByUser(at(266), answeredCheckId = aboutA))
        val still = detector.snapshot(at(266))
        assertFalse("the rider has not said they are on B", still.hasBoarded)
        assertEquals("and B's question is still theirs to answer", aboutB.boardingCheckId, still.boardingCheckId)
        assertTrue(still.boardingPromptDue)

        // Said with no question attached, "I have boarded" is always heard.
        assertTrue(detector.confirmBoardedByUser(at(270)))
        assertTrue(detector.snapshot(at(270)).hasBoarded)
    }

    @Test
    fun aRiderCarriedOnAlongTheRouteHasNotWalkedAwayFromTheQuestion() {
        // No vehicle positions. The estimate runs out and rolls over; a
        // quarter of a minute later the phone is 420 m down the route — too
        // soon to be asked, and not yet far enough to be a ride by itself.
        val detector = newDetector()
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        val asked = detector.snapshot(at(20)).boardingCheckId
        assertTrue(asked != 0L)
        detector.onUserLocation(RideGeoPoint(latitude(420.0), 120.6, at(35), accuracyMeters = 10f))
        val onTheWay = detector.snapshot(at(35))
        assertFalse(onTheWay.hasBoarded)
        assertEquals("that may be the bus carrying them off", asked, onTheWay.boardingCheckId)

        // The fixes stop there. The question is all that is left to ask with.
        val later = detector.snapshot(at(65))
        assertEquals(asked, later.boardingCheckId)
        assertTrue(later.boardingPromptDue)
    }

    @Test
    fun aRiderGoneFromTheStopAnyOtherWayHasWalkedAwayFromTheQuestion() {
        // 420 m off to one side of the route; and 420 m back up it.
        val aside = newDetector()
        aside.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        aside.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        assertTrue(aside.snapshot(at(20)).boardingCheckId != 0L)
        aside.onUserLocation(RideGeoPoint(latitude(0.0), 120.6041, at(35), accuracyMeters = 10f))
        assertEquals(0L, aside.snapshot(at(35)).boardingCheckId)

        // Level with a point further down the route, but on another road.
        val alongside = newDetector()
        alongside.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        alongside.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        assertTrue(alongside.snapshot(at(20)).boardingCheckId != 0L)
        alongside.onUserLocation(RideGeoPoint(latitude(300.0), 120.6041, at(35), accuracyMeters = 10f))
        assertEquals(0L, alongside.snapshot(at(35)).boardingCheckId)

        val back = newDetector(boardingStopId = 2)
        back.onBoardingStopEta(0, arriving = true, nowMs = at(0))
        back.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        assertTrue(back.snapshot(at(20)).boardingCheckId != 0L)
        back.onUserLocation(RideGeoPoint(latitude(80.0), 120.6, at(35), accuracyMeters = 10f))
        assertEquals(0L, back.snapshot(at(35)).boardingCheckId)
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
    fun aRidePickedBackUpOnAKnownBusIsMeasuredByThatBus() {
        // No phone. The ride was on BUS when it was paused; the detector is
        // new, and BUS is now two kilometres along, with another at the stop.
        val detector = newDetector()
        detector.resumeConfirmedRide(knownVehicleId = BUS)
        detector.onBusReports(listOf(report(0, along = 1_000.0), report(0, along = 0.0, id = "NEXT-BUS")))

        val ride = detector.snapshot(at(0))
        assertTrue(ride.hasBoarded)
        assertEquals(BUS, ride.trackedVehicleId)
        assertEquals(1, ride.remainingStops)
        assertEquals(500.0, ride.destinationDistanceMeters!!, 1.0)
        assertTrue(ride.hasRouteValidProgress)
    }

    @Test
    fun aVariantsBusCountsOnlyWhereItsRouteSharesThisOnes() {
        // The variant calls at the second to the fourth of these six stops.
        val shared = setOf(2, 3, 4)
        fun variant(seconds: Long, along: Double) = report(seconds, along).copy(servedStopIds = shared)
        val detector = newDetector(boardingStopId = 2)
        detector.onBusReports(listOf(variant(0, along = 500.0)))
        detector.confirmBoardedByUser(at(0))
        assertEquals(BUS, detector.snapshot(at(0)).trackedVehicleId)

        detector.onBusReports(listOf(variant(60, along = 1_000.0)))
        val between = detector.snapshot(at(60))
        assertEquals(2, between.progressStopIndex)
        assertTrue(between.hasRouteValidProgress)

        // Past the last stop it shares, its place along this route means nothing.
        detector.onBusReports(listOf(variant(120, along = 1_900.0)))
        val beyond = detector.snapshot(at(120))
        assertEquals("it is still the rider's bus", BUS, beyond.trackedVehicleId)
        assertEquals(-1, beyond.progressStopIndex)
        assertFalse(beyond.hasRouteValidProgress)
        assertNull(beyond.passedDestinationByStops)

        // Nor before the first: it is not coming up to the boarding stop here.
        val approaching = newDetector(boardingStopId = 2)
        approaching.onBusReports(listOf(variant(0, along = 100.0)))
        assertNull(approaching.snapshot(at(0)).nextBusVehicleId)
        // A bus of the route itself, in the same place, is.
        approaching.onBusReports(listOf(report(0, along = 100.0, id = "MAIN")))
        assertEquals("MAIN", approaching.snapshot(at(0)).nextBusVehicleId)
    }

    @Test
    fun aBusTwoRoutesOfTheFamilyListRunsWhereEitherOfThemDoes() {
        // The same fix of the same bus, from the variant's endpoint and from
        // the route's own, in either order: the route's own says it runs here.
        val shared = setOf(2, 3, 4)
        for (variantAnswersFirst in listOf(true, false)) {
            val detector = newDetector(boardingStopId = 2)
            fun both(seconds: Long, along: Double) {
                val own = report(seconds, along)
                val variant = own.copy(servedStopIds = shared)
                (if (variantAnswersFirst) listOf(variant, own) else listOf(own, variant))
                    .forEach { detector.onBusReports(listOf(it)) }
            }
            both(0, along = 500.0)
            detector.confirmBoardedByUser(at(0))
            both(60, along = 1_000.0)
            both(120, along = 2_400.0)
            val beyond = detector.snapshot(at(120))
            assertEquals("variant first: $variantAnswersFirst", BUS, beyond.trackedVehicleId)
            assertTrue("variant first: $variantAnswersFirst", beyond.hasRouteValidProgress)
            assertEquals("variant first: $variantAnswersFirst", 4, beyond.progressStopIndex)
        }

        // Two variants that list it: where either of their routes runs.
        val detector = newDetector(boardingStopId = 2)
        val early = report(0, along = 500.0)
        detector.onBusReports(listOf(early.copy(servedStopIds = setOf(1, 2))))
        detector.onBusReports(listOf(early.copy(servedStopIds = setOf(5, 6))))
        detector.confirmBoardedByUser(at(0))
        val late = report(60, along = 2_100.0)
        detector.onBusReports(listOf(late.copy(servedStopIds = setOf(1, 2))))
        assertFalse(detector.snapshot(at(60)).hasRouteValidProgress)
        detector.onBusReports(listOf(late.copy(servedStopIds = setOf(5, 6))))
        assertTrue(detector.snapshot(at(60)).hasRouteValidProgress)
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
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = listOfNotNull(atStop).map(::atTheStop))
            detector.snapshot(at(0))
            detector.onBusReports(listOf(report(20, along = 150.0)))
            val asked = detector.snapshot(at(20)).boardingCheckId
            assertTrue(asked != 0L)
            detector.onBoardingStopEta(600, arriving = false, nowMs = at(50))
            if (aSecondRollover) {
                detector.onBoardingStopEta(0, arriving = true, nowMs = at(60), buses = listOfNotNull(atStop).map(::atTheStop))
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
        // stop, then [later], and then the ETA rolls over. A null [later] is
        // an update that says nothing of any bus, only that the stop's
        // estimate stands at zero.
        fun answer(later: List<String>?): RideSnapshot {
            val detector = newDetector()
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = listOf(atTheStop("BUS-A")))
            detector.onBoardingStopEta(
                0, arriving = later != null, nowMs = at(20), buses = later.orEmpty().map(::atTheStop),
            )
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
        // Still A, or an update that says nothing of any bus.
        assertEquals("BUS-A", answer(listOf("BUS-A")).trackedVehicleId)
        assertEquals("BUS-A", answer(null).trackedVehicleId)
        // The feed saying a bus is arriving, and listing none that is: one is
        // there that it has not named.
        assertUnidentified(answer(emptyList()))
    }

    @Test
    fun aBusAtTheStopTheFeedDidNotNameLeavesTheRolloverUnnamed() {
        // A is named at the stop; and the feed has a bus there with no plate —
        // before A, or after it.
        for (unnamedFirst in listOf(true, false)) {
            val detector = newDetector()
            val named = listOf(atTheStop("BUS-A"))
            val unnamed = listOf(StopFeedBus(vehicleId = null, etaSeconds = 0, arriving = true))
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = if (unnamedFirst) unnamed else named)
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(20), buses = if (unnamedFirst) named else unnamed)
            detector.onBoardingStopEta(600, arriving = false, nowMs = at(40))
            val asked = detector.snapshot(at(85))
            assertTrue(asked.boardingPromptDue)
            detector.confirmBoardedByUser(at(90), answeredCheckId = asked.boardingCheckId)

            assertUnidentified(detector.snapshot(at(90)))
        }
    }

    @Test
    fun aBusFlaggedAsArrivingIsAtTheStopWhateverItsEstimate() {
        val detector = newDetector()
        val flagged = listOf(StopFeedBus("BUS-A", etaSeconds = 95, arriving = true))
        detector.onBoardingStopEta(95, arriving = true, nowMs = at(0), buses = flagged)
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        val asked = detector.snapshot(at(65))
        assertTrue(asked.boardingPromptDue)
        detector.confirmBoardedByUser(at(70), answeredCheckId = asked.boardingCheckId)
        assertEquals("BUS-A", detector.snapshot(at(70)).trackedVehicleId)

        // Unflagged, a bus that far out is not at the stop, and nothing left.
        val unflagged = newDetector()
        unflagged.onBoardingStopEta(95, arriving = false, nowMs = at(0), buses = listOf(StopFeedBus("BUS-A", 95)))
        unflagged.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        assertFalse(unflagged.snapshot(at(65)).boardingPromptDue)
    }

    @Test
    fun eachRoutesEstimateForTheStopIsReadByItself() {
        fun feed(detector: TripRideDetector, seconds: Long, main: Int?, variant: Int?, variantIsNew: Boolean = true) =
            detector.onBoardingStopFeed(
                listOf(StopEstimate("MAIN", main), StopEstimate("VARIANT", variant, observedNow = variantIsNew)),
                nowMs = at(seconds),
            )

        // One route's estimate ran out unwatched; the other's bus is due.
        val mixed = newDetector()
        feed(mixed, 0, main = -1, variant = 0)
        feed(mixed, 20, main = 600, variant = 600)
        assertTrue("the bus that was due has left", mixed.snapshot(at(20)).boardingCheckId != 0L)

        // A countdown one route was watched through is not another's.
        val unwatched = newDetector()
        feed(unwatched, 0, main = 100, variant = null)
        feed(unwatched, 20, main = 80, variant = -1)
        feed(unwatched, 40, main = 600, variant = 600)
        assertEquals("nothing was due on either", 0L, unwatched.snapshot(at(40)).boardingCheckId)

        // Nor does one route's bus still to come hide the other's at the stop.
        val watched = newDetector()
        feed(watched, 0, main = 300, variant = 20)
        feed(watched, 20, main = 280, variant = -1)
        assertEquals(0L, watched.snapshot(at(20)).boardingCheckId)
        feed(watched, 40, main = 260, variant = 900)
        assertTrue("the variant's bus was at the stop, and has gone", watched.snapshot(at(40)).boardingCheckId != 0L)

        // A bus one route has at the stop, that route not observed again, has
        // not left because the other route's estimate is all that is new.
        val standing = newDetector()
        feed(standing, 0, main = 600, variant = 20)
        feed(standing, 20, main = 580, variant = -1)
        feed(standing, 40, main = 560, variant = -1, variantIsNew = false)
        assertEquals(0L, standing.snapshot(at(40)).boardingCheckId)
        feed(standing, 60, main = 540, variant = 900)
        assertTrue(standing.snapshot(at(60)).boardingCheckId != 0L)

        // A route not observed again still has its bus due: the other moving
        // on is not that bus leaving, and it is not that bus arriving again.
        val held = newDetector()
        feed(held, 0, main = 600, variant = 0)
        feed(held, 100, main = 500, variant = 0, variantIsNew = false)
        assertEquals(0L, held.snapshot(at(100)).boardingCheckId)
        // Had it been due all over again at 100 s, this would be inside the window.
        feed(held, 200, main = 400, variant = 900)
        assertEquals("the arrival it opened has long lapsed", 0L, held.snapshot(at(200)).boardingCheckId)
    }

    @Test
    fun aBusOneRouteFlagsAsArrivingIsThatRoutesToSay() {
        // The variant flags its bus as arriving; [variantIsNew] is whether it
        // was observed again. The route itself only ever has a bus far off.
        fun feed(
            detector: TripRideDetector,
            seconds: Long,
            main: Int?,
            variant: Int?,
            variantArriving: Boolean,
            variantIsNew: Boolean = true,
        ) = detector.onBoardingStopFeed(
            listOf(
                StopEstimate("MAIN", main),
                StopEstimate("VARIANT", variant, observedNow = variantIsNew, arriving = variantArriving),
            ),
            nowMs = at(seconds),
            buses = listOfNotNull(
                StopFeedBus("BUS-V", variant, arriving = true, observedNow = variantIsNew).takeIf { variantArriving },
            ),
        )

        // Flagged once, then not observed again while the route itself is:
        // the bus is neither arriving again, nor gone.
        val held = newDetector()
        feed(held, 0, main = 600, variant = -1, variantArriving = true)
        feed(held, 100, main = 500, variant = -1, variantArriving = true, variantIsNew = false)
        assertEquals(0L, held.snapshot(at(100)).boardingCheckId)
        // Had it arrived all over again at 100 s, this would be inside the window.
        feed(held, 200, main = 400, variant = 900, variantArriving = false)
        assertEquals("the arrival it opened has long lapsed", 0L, held.snapshot(at(200)).boardingCheckId)

        // Observed again without the flag, it has left; and it is the one bus
        // the feed placed at the stop.
        val left = newDetector()
        feed(left, 0, main = 600, variant = -1, variantArriving = true)
        feed(left, 20, main = 580, variant = -1, variantArriving = true, variantIsNew = false)
        feed(left, 40, main = 560, variant = 900, variantArriving = false)
        val asked = left.snapshot(at(85))
        assertTrue(asked.boardingPromptDue)
        left.confirmBoardedByUser(at(90), asked.boardingCheckId)
        assertEquals("BUS-V", left.snapshot(at(90)).trackedVehicleId)

        // One route's flag is not a countdown watched on another. The route
        // itself, run out with nothing seen counting down to it, has no bus
        // due of its own, and does not keep the variant's at the stop.
        val unwatched = newDetector()
        feed(unwatched, 0, main = 600, variant = -1, variantArriving = true)
        feed(unwatched, 20, main = -1, variant = 900, variantArriving = false)
        assertTrue("the flagged bus has left", unwatched.snapshot(at(20)).boardingCheckId != 0L)

        // A flag with no estimate beside it is a bus due all the same.
        val flagOnly = newDetector()
        feed(flagOnly, 0, main = 600, variant = null, variantArriving = true)
        feed(flagOnly, 20, main = 580, variant = null, variantArriving = false)
        assertTrue(flagOnly.snapshot(at(20)).boardingCheckId != 0L)
    }

    @Test
    fun aBusListedForTheStopIsNotABusAtTheStop() {
        // The feed lists every bus heading for the stop, with its estimate.
        // [coming] are the ones still on their way while A stands there.
        fun answer(vararg coming: Pair<String, Int?>): RideSnapshot {
            val detector = newDetector()
            val onTheWay = coming.map { (id, eta) -> StopFeedBus(id, eta) }
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = listOf(atTheStop("BUS-A")) + onTheWay)
            // A leaves: the stop's estimate is now the next bus's.
            detector.onBoardingStopEta(coming.firstOrNull()?.second ?: 600, arriving = false, nowMs = at(20), buses = onTheWay)
            val asked = detector.snapshot(at(65))
            assertTrue("a bus has left, whatever is still listed", asked.boardingPromptDue)
            detector.confirmBoardedByUser(at(70), answeredCheckId = asked.boardingCheckId)
            return detector.snapshot(at(70))
        }
        // Buses a quarter of an hour and more away are not the one that left.
        assertEquals("BUS-A", answer("BUS-B" to 811, "BUS-C" to 1_231).trackedVehicleId)
        assertEquals("BUS-A", answer("BUS-B" to 811).trackedVehicleId)
        // One four minutes away is not at the stop either, and has not been.
        assertEquals("BUS-A", answer("BUS-B" to 240).trackedVehicleId)
    }

    @Test
    fun aBusCloseBehindMayHaveComeAndGoneBetweenTwoPolls() {
        // A at the stop and B a minute and a half behind; the next thing the
        // feed shows is the bus after those. Either may have been boarded.
        val detector = newDetector()
        detector.onBoardingStopEta(
            0, arriving = true, nowMs = at(0),
            buses = listOf(atTheStop("BUS-A"), StopFeedBus("BUS-B", 90), StopFeedBus("BUS-C", 900)),
        )
        detector.onBoardingStopEta(880, arriving = false, nowMs = at(100), buses = listOf(StopFeedBus("BUS-C", 880)))
        val asked = detector.snapshot(at(145))
        assertTrue(asked.boardingPromptDue)
        detector.confirmBoardedByUser(at(150), answeredCheckId = asked.boardingCheckId)

        assertUnidentified(detector.snapshot(at(150)))
    }

    @Test
    fun aBusOnlyEverListedOnItsWayNeverLeft() {
        // Nothing has been at the stop: one bus is listed for it, a quarter of
        // an hour out, and its estimate is revised.
        val detector = newDetector()
        detector.onBoardingStopEta(811, arriving = false, nowMs = at(0), buses = listOf(StopFeedBus("BUS-B", 811)))
        detector.onBoardingStopEta(900, arriving = false, nowMs = at(20), buses = listOf(StopFeedBus("BUS-B", 900)))

        assertEquals(0L, detector.snapshot(at(20)).boardingCheckId)
        assertFalse(detector.snapshot(at(70)).boardingPromptDue)
    }

    @Test
    fun anEstimateThatHasRunOutIsABusOnlyAtTheEndOfACountdown() {
        // The backend counts an estimate down to -1 and leaves it there.
        fun asked(vararg polls: Triple<Long, Int?, Boolean>): Boolean {
            val detector = newDetector()
            polls.forEach { (seconds, eta, arriving) ->
                detector.onBoardingStopEta(eta, arriving = arriving, nowMs = at(seconds))
            }
            return detector.snapshot(at(polls.last().first)).boardingCheckId != 0L
        }
        // With nothing before it, it is a stop nobody is counting down to.
        assertFalse(asked(Triple(0L, -1, false), Triple(20L, 600, false)))
        assertFalse(asked(Triple(0L, -1, false), Triple(20L, -1, false), Triple(40L, null, false)))
        // After an estimate that was running, it is that bus now due — which
        // is all a feed that never flags an arrival has to say.
        assertTrue(asked(Triple(0L, 67, false), Triple(15L, -1, false), Triple(30L, null, false)))
        assertTrue(asked(Triple(0L, 67, false), Triple(15L, -1, false), Triple(30L, 600, false)))
        // And one the feed flags as arriving is a bus whatever its estimate.
        assertTrue(asked(Triple(0L, -1, true), Triple(20L, 600, false)))
        // Left standing for minutes, it is stale, not a bus still due.
        assertFalse(
            asked(
                Triple(0L, 67, false), Triple(100L, -1, false), Triple(200L, -1, false), Triple(300L, 600, false),
            ),
        )
    }

    @Test
    fun aBusTheStopFeedHasAtTheStopLeavesAnAnswerAboutAnotherOpen() {
        // A, seen by its positions, leaves and is asked about. Before the
        // rider answers, the stop feed has B arriving; B has no position feed.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        detector.snapshot(at(20))
        val asked = detector.snapshot(at(60)).boardingCheckId
        assertTrue(asked != 0L)
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(65), buses = listOf(atTheStop("BUS-B")))
        detector.confirmBoardedByUser(at(70), answeredCheckId = asked)

        assertUnidentified(detector.snapshot(at(70)))
    }

    @Test
    fun unpromptedABusOnlyTheStopFeedHasAtTheStopLeavesTheRideUnidentified() {
        // The stop feed has A and B both at the stop; only A reports a position.
        fun confirm(stopFeed: List<StopFeedBus>): RideSnapshot {
            val detector = newDetector()
            detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
            detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = stopFeed)
            detector.confirmBoardedByUser(at(5))
            return detector.snapshot(at(5))
        }
        assertUnidentified(confirm(listOf(atTheStop("BUS-A"), atTheStop("BUS-B"))))
        // A alone there, with B merely on its way, is A.
        assertEquals("BUS-A", confirm(listOf(atTheStop("BUS-A"), StopFeedBus("BUS-B", 400))).trackedVehicleId)
    }

    /** A bus the stop feed flags as arriving, its own estimate at zero. */
    private fun atTheStop(vehicleId: String) = StopFeedBus(vehicleId, etaSeconds = 0, arriving = true)

    @Test
    fun theNextArrivalStartsWithNoPlatesFromTheLast() {
        val detector = newDetector()
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(0), buses = listOf(atTheStop("BUS-A")))
        detector.onBoardingStopEta(600, arriving = false, nowMs = at(20))
        val first = detector.snapshot(at(65))
        detector.declineBoarding(at(70), answeredCheckId = first.boardingCheckId)
        detector.onBoardingStopEta(0, arriving = true, nowMs = at(200), buses = listOf(atTheStop("BUS-B")))
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

    // ---- an identified ride keeps its bus -----------------------------------

    @Test
    fun anIdentifiedRideIsNotHandedToTheNextBusWhenThePhoneGoesQuiet() {
        // On A at the boarding stop, phone and bus together. Then the phone
        // stops reporting, and a minute later A is 700 m on with B at the stop.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.onUserLocation(fix(0, along = 0.0))
        detector.confirmBoardedByUser(at(0))
        assertEquals("BUS-A", detector.snapshot(at(0)).trackedVehicleId)

        detector.reportBoth(60, a = 700.0, b = 0.0)
        val quiet = detector.snapshot(at(60))
        assertEquals(
            "where the phone was a minute ago does not show the rider got off A",
            "BUS-A",
            quiet.trackedVehicleId,
        )

        // The fix lapses altogether, and it is A that carries the ride on.
        detector.reportBoth(100, a = 1_000.0, b = 300.0)
        val ride = detector.snapshot(at(100))
        assertFalse(ride.hasUsableLocation)
        assertEquals("BUS-A", ride.trackedVehicleId)
        assertEquals(2, ride.progressStopIndex)
    }

    @Test
    fun aVehicleReportIsHeldAgainstWhereTheRiderWasWhenItWasMade() {
        // A fix twenty seconds old, at the stop. A's report, made after it,
        // has A 400 m on; B is pulling in. Nothing says where the rider was
        // when A reported — on A, for all the fix shows.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.onUserLocation(fix(0, along = 0.0))
        detector.confirmBoardedByUser(at(0))
        assertEquals("BUS-A", detector.snapshot(at(0)).trackedVehicleId)
        detector.reportBoth(20, a = 400.0, b = 0.0)

        assertEquals("BUS-A", detector.snapshot(at(20)).trackedVehicleId)
    }

    @Test
    fun aVehicleFeedOutageWithAFixStillInHandDoesNotMoveTheRide() {
        // A's feed stops. The last fix, at the stop and still usable, lies
        // beside another bus when that one reports.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.confirmBoardedByUser(at(0))
        assertEquals("BUS-A", detector.snapshot(at(0)).trackedVehicleId)
        detector.onUserLocation(fix(150, along = 0.0))
        detector.onBusReports(listOf(report(200, along = 50.0, id = "BUS-B")))

        val outage = detector.snapshot(at(200))
        assertTrue(outage.hasUsableLocation)
        assertEquals("BUS-A", outage.trackedVehicleId)
    }

    @Test
    fun aFreshFixThatAnotherBusExplainsStillMovesTheRideToIt() {
        // Co-movement can lock on to the wrong one of two buses running close
        // together. The rider's own position, current, sorts that out.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.onUserLocation(fix(0, along = 0.0))
        detector.confirmBoardedByUser(at(0))
        assertEquals("BUS-A", detector.snapshot(at(0)).trackedVehicleId)

        // A has run 700 m ahead; the rider is at the stop still, with B.
        detector.reportBoth(60, a = 700.0, b = 0.0)
        detector.onUserLocation(fix(58, along = 5.0))
        assertEquals("BUS-B", detector.snapshot(at(60)).trackedVehicleId)
    }

    @Test
    fun aBusThatFallsSilentIsNotReplacedByOneThatHappensToBeNear() {
        // Riding A with the phone reporting. A's feed stops; B is 200 m behind
        // the rider. The rider is still on A.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.onUserLocation(fix(0, along = 0.0))
        detector.confirmBoardedByUser(at(0))
        detector.onBusReports(listOf(report(30, along = 250.0, id = "BUS-A")))
        detector.onUserLocation(fix(30, along = 250.0))
        assertEquals("BUS-A", detector.snapshot(at(30)).trackedVehicleId)

        for (seconds in listOf(60L, 120L, 180L, 240L)) {
            detector.onUserLocation(fix(seconds, along = 250.0 + 4.0 * (seconds - 30)))
            detector.onBusReports(listOf(report(seconds, along = 50.0 + 4.0 * (seconds - 30), id = "BUS-B")))
            detector.snapshot(at(seconds))
        }
        // A is long past being a live vehicle by now.
        assertEquals("BUS-A", detector.snapshot(at(240)).trackedVehicleId)

        // Not heard from for more than six minutes, it is no longer anything
        // to hold on to, and the ride is placed afresh from the rider's own
        // position, as one with no vehicle would be.
        for (seconds in listOf(300L, 360L, 420L)) {
            detector.onUserLocation(fix(seconds, along = 250.0 + 4.0 * (seconds - 30)))
            detector.onBusReports(listOf(report(seconds, along = 50.0 + 4.0 * (seconds - 30), id = "BUS-B")))
            detector.snapshot(at(seconds))
        }
        assertEquals("BUS-B", detector.snapshot(at(420)).trackedVehicleId)
    }

    // ---- a bus the rider turned down ----------------------------------------

    @Test
    fun confirmingByHandDoesNotPutTheRiderBackOnABusTheyTurnedDown() {
        // A left and the rider said "not yet". It is held up 200 m past the
        // stop when the rider, still at the stop, boards a bus with no
        // position feed and says so.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0, id = "BUS-A")))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 150.0, id = "BUS-A")))
        detector.snapshot(at(20))
        val asked = detector.snapshot(at(60)).boardingCheckId
        assertTrue(asked != 0L)
        detector.declineBoarding(at(65), answeredCheckId = asked)

        detector.onUserLocation(fix(70, along = 0.0))
        detector.onBusReports(listOf(report(70, along = 200.0, id = "BUS-A")))
        detector.confirmBoardedByUser(at(75))
        val confirmed = detector.snapshot(at(75))
        assertTrue(confirmed.hasBoarded)
        assertNull("A is the one bus the rider has said they are not on", confirmed.trackedVehicleId)

        // The phone goes quiet and A drives on past the rider's destination.
        detector.onBusReports(listOf(report(200, along = 2_000.0, id = "BUS-A")))
        val later = detector.snapshot(at(200))
        assertNull(later.trackedVehicleId)
        assertNull("and it must not carry the ride past the destination", later.passedDestinationByStops)
    }

    @Test
    fun aRideDetectedOnABusLaterTurnedDownByNameIsNotKept() {
        // Turned down while it was the detected ride, A is not picked up again
        // by a later confirmation either.
        val detector = newDetector()
        for (seconds in 0L..60L step 20L) {
            detector.onBusReports(listOf(report(seconds, along = 5.0 * seconds, id = "BUS-A")))
            detector.onUserLocation(fix(seconds, along = 5.0 * seconds))
            detector.snapshot(at(seconds))
        }
        assertEquals("BUS-A", detector.snapshot(at(60)).trackedVehicleId)
        detector.declineBoarding(at(61))

        detector.onUserLocation(fix(80, along = 400.0))
        detector.onBusReports(listOf(report(80, along = 400.0, id = "BUS-A")))
        detector.confirmBoardedByUser(at(85))
        assertNull(detector.snapshot(at(85)).trackedVehicleId)
    }

    // ---- a vehicle position that cannot be right ------------------------------

    @Test
    fun aVehicleCannotCarryTheRidePastTheDestinationInOneLeap() {
        // No phone. Riding A from the first stop; twenty seconds later it
        // reports from two kilometres down the route.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(0))
        assertEquals(BUS, detector.snapshot(at(0)).trackedVehicleId)

        detector.onBusReports(listOf(report(20, along = 2_000.0)))
        val leapt = detector.snapshot(at(20))
        assertEquals("still the rider's bus", BUS, leapt.trackedVehicleId)
        assertNull("100 m/s is not a bus", leapt.passedDestinationByStops)
        assertFalse(leapt.hasRouteValidProgress)
        assertEquals(-1, leapt.progressStopIndex)
        // Nor a minute later, with nothing new to go on.
        assertNull(detector.snapshot(at(65)).passedDestinationByStops)
        assertFalse(detector.snapshot(at(80)).hasRouteValidProgress)
    }

    @Test
    fun aVehicleThatGoesOnReportingFromItsNewPlaceIsBelievedThere() {
        // The leap was real after all: a gap in its own records, say. Its next
        // report agrees with where the leap put it.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(0))
        detector.onBusReports(listOf(report(20, along = 2_000.0)))
        assertFalse(detector.snapshot(at(20)).hasRouteValidProgress)

        detector.onBusReports(listOf(report(40, along = 2_150.0)))
        val ride = detector.snapshot(at(40))
        assertTrue(ride.hasRouteValidProgress)
        assertEquals(4, ride.progressStopIndex)
        assertEquals(1, ride.passedDestinationByStops)
    }

    @Test
    fun aSingleWildPositionDoesNotDisturbTheRide() {
        // One bad fix, and the bus is back where it should be on the next.
        val detector = newDetector()
        detector.onBusReports(listOf(report(0, along = 0.0)))
        detector.confirmBoardedByUser(at(0))
        detector.onBusReports(listOf(report(20, along = 2_000.0)))
        assertFalse(detector.snapshot(at(20)).hasRouteValidProgress)

        detector.onBusReports(listOf(report(40, along = 300.0)))
        val ride = detector.snapshot(at(40))
        assertTrue(ride.hasRouteValidProgress)
        assertEquals(0, ride.progressStopIndex)
        assertEquals(3, ride.remainingStops)
        assertNull(ride.passedDestinationByStops)
    }

    @Test
    fun aWildPositionDoesNotAnnounceADeparture() {
        // A bus waiting short of the boarding stop reports, once, from far
        // down the route. Nobody at the stop has seen a bus leave.
        val detector = newDetector(boardingStopId = 2)
        detector.onBusReports(listOf(report(0, along = 450.0)))
        assertEquals(0L, detector.snapshot(at(0)).boardingCheckId)

        detector.onBusReports(listOf(report(20, along = 2_400.0)))
        assertEquals(0L, detector.snapshot(at(20)).boardingCheckId)
        detector.onBusReports(listOf(report(40, along = 470.0)))
        assertEquals(0L, detector.snapshot(at(40)).boardingCheckId)

        // When it really does pull away, that is asked about as usual.
        detector.onBusReports(listOf(report(60, along = 500.0)))
        detector.snapshot(at(60))
        detector.onBusReports(listOf(report(80, along = 650.0)))
        assertTrue(detector.snapshot(at(80)).boardingCheckId != 0L)
    }

    @Test
    fun aVehicleThatLeaptPastTheStopWasNotSeenLeavingIt() {
        // Short of the boarding stop, and then — in two reports that agree —
        // two kilometres beyond it. It is there, but no bus drove past the
        // stop in those twenty seconds for anyone to have boarded.
        val detector = newDetector(boardingStopId = 2)
        detector.onBusReports(listOf(report(0, along = 450.0)))
        detector.snapshot(at(0))
        detector.onBusReports(listOf(report(20, along = 2_400.0)))
        detector.snapshot(at(20))
        detector.onBusReports(listOf(report(40, along = 2_450.0)))

        assertEquals(0L, detector.snapshot(at(40)).boardingCheckId)
    }

    private fun fix(seconds: Long, along: Double) = RideGeoPoint(
        latitude(along), 120.6, at(seconds), accuracyMeters = 10f, speedMetersPerSecond = null,
    )

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
