package tw.avianjay.taiwanbus.flutter

import java.io.File
import java.util.Calendar
import java.util.TimeZone
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SmartRouteReminderRulesTest {
    private val taipei = TimeZone.getTimeZone("Asia/Taipei")

    /** A moment on the wall clock in Taipei. 2026-04-08 is a Wednesday. */
    private fun at(day: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance(taipei).apply {
            clear()
            set(2026, Calendar.APRIL, day, hour, minute)
        }.timeInMillis

    private fun slot(
        weekday: Int = 3,
        routeKey: Int = 101,
        pathId: Int = 0,
        provider: String = "khh",
        startMinute: Int = 190,
        endMinute: Int = 250,
        peakMinute: Int = 220,
        confidence: Double = 0.9,
        validUntilMs: Long = at(22, 4, 0),
        lastActivityAtMs: Long = at(7, 7, 40),
        stopId: Long? = 100100128221,
    ) = SmartPlanSlot(
        provider = provider,
        routeKey = routeKey,
        routeId = "KHH$routeKey",
        pathId = pathId,
        routeName = "307",
        weekday = weekday,
        startMinute = startMinute,
        endMinute = endMinute,
        peakMinute = peakMinute,
        confidence = confidence,
        supportDays = 15,
        validUntilMs = validUntilMs,
        lastActivityAtMs = lastActivityAtMs,
        stopId = stopId,
    )

    private fun plan(vararg slots: SmartPlanSlot) =
        SmartRoutePlan(version = 1, dayStartHour = 4, slots = slots.toList())

    private fun stop(rawStopId: String, pathId: Int = 0, name: String = "站") =
        SmartRouteStop(
            pathId = pathId,
            rawStopId = rawStopId,
            stopName = name,
            sequence = 1,
            lon = 120.3,
            lat = 22.6,
        )

    // --- the plan -----------------------------------------------------------

    @Test
    fun readsThePlanTheFlutterSideWrites() {
        // The same file SmartRoutePlanner's own test compares its output to.
        val plan = SmartRouteReminderRules.parsePlan(sharedFixture().readText())

        assertNotNull(plan)
        assertEquals(4, plan!!.dayStartHour)
        assertEquals(6, plan.slots.size)
        val monday = plan.slots.first()
        assertEquals("khh", monday.provider)
        assertEquals(101, monday.routeKey)
        assertEquals("KHH101", monday.routeId)
        assertEquals(0, monday.pathId)
        assertEquals("307", monday.routeName)
        assertEquals(1, monday.weekday)
        assertEquals(190, monday.startMinute)
        assertEquals(250, monday.endMinute)
        assertEquals(220, monday.peakMinute)
        assertEquals(0.918, monday.confidence, 1e-9)
        assertEquals(15, monday.supportDays)
        assertEquals(1776801600000L, monday.validUntilMs)
        assertEquals(1775518800000L, monday.lastActivityAtMs)
        // Too wide for an Int: the reason this field is a Long.
        assertEquals(100100128221L, monday.stopId)
        val saturday = plan.slots.last()
        assertEquals(6, saturday.weekday)
        assertEquals("紅12", saturday.routeName)
        assertNull(saturday.stopId)
    }

    @Test
    fun ignoresAPlanItCannotTrust() {
        val valid = sharedFixture().readText()

        assertNull(SmartRouteReminderRules.parsePlan(null))
        assertNull(SmartRouteReminderRules.parsePlan("  "))
        assertNull(SmartRouteReminderRules.parsePlan("{not json"))
        assertNull(SmartRouteReminderRules.parsePlan("""{"slots": []}"""))
        assertNull(
            SmartRouteReminderRules.parsePlan(valid.replace("\"version\": 1", "\"version\": 2")),
        )
        assertNull(
            SmartRouteReminderRules.parsePlan(
                valid.replace("\"dayStartHour\": 4", "\"dayStartHour\": 24"),
            ),
        )
        // A field added by a later writer is not a reason to stop reading.
        assertNotNull(
            SmartRouteReminderRules.parsePlan(
                valid.replace("\"version\": 1", "\"version\": 1, \"note\": \"x\""),
            ),
        )
    }

    // --- the clock ----------------------------------------------------------

    @Test
    fun aServiceDayRunsFromFourToFour() {
        val morning = SmartRouteReminderRules.serviceClock(at(8, 7, 40), 4, taipei)
        val justBeforeFour = SmartRouteReminderRules.serviceClock(at(8, 3, 59), 4, taipei)
        val atFour = SmartRouteReminderRules.serviceClock(at(8, 4, 0), 4, taipei)

        assertEquals(3, morning.weekday)
        assertEquals(220, morning.minute)
        // 03:59 on Wednesday still belongs to Tuesday.
        assertEquals(2, justBeforeFour.weekday)
        assertEquals(23 * 60 + 59, justBeforeFour.minute)
        assertEquals(3, atFour.weekday)
        assertEquals(0, atFour.minute)
        assertEquals(morning.day, atFour.day)
        assertTrue(justBeforeFour.day != atFour.day)
    }

    @Test
    fun weekdaysCountFromMonday() {
        // 2026-04-06 is a Monday, 2026-04-12 a Sunday.
        assertEquals(
            listOf(1, 2, 3, 4, 5, 6, 7),
            (6..12).map { SmartRouteReminderRules.serviceClock(at(it, 12, 0), 4, taipei).weekday },
        )
    }

    // --- when a slot is due -------------------------------------------------

    @Test
    fun aSlotIsDueFromALittleBeforeTheUsualTimeUntilItsWindowEnds() {
        val plan = plan(slot())
        fun dueAt(hour: Int, minute: Int) =
            SmartRouteReminderRules.dueSlots(plan, "khh", at(8, hour, minute), taipei).size

        // Usual time 07:40, window 07:10 to 08:10, lead fifteen minutes.
        assertEquals(0, dueAt(7, 10))
        assertEquals(0, dueAt(7, 24))
        assertEquals(1, dueAt(7, 25))
        assertEquals(1, dueAt(7, 40))
        assertEquals(1, dueAt(8, 10))
        assertEquals(0, dueAt(8, 11))
    }

    @Test
    fun aNarrowWindowIsNotOpenedEarlyByTheLead() {
        val plan = plan(slot(startMinute = 215, endMinute = 225))

        assertEquals(
            0,
            SmartRouteReminderRules.dueSlots(plan, "khh", at(8, 7, 34), taipei).size,
        )
        assertEquals(
            1,
            SmartRouteReminderRules.dueSlots(plan, "khh", at(8, 7, 35), taipei).size,
        )
    }

    @Test
    fun aSlotIsOnlyDueOnItsWeekdayForItsProviderAndWhileValid() {
        val now = at(8, 7, 40)
        fun due(slot: SmartPlanSlot, provider: String = "khh") =
            SmartRouteReminderRules.dueSlots(plan(slot), provider, now, taipei).size

        assertEquals(1, due(slot()))
        assertEquals(0, due(slot(weekday = 2)))
        assertEquals(0, due(slot(), provider = "tpe"))
        assertEquals(0, due(slot(validUntilMs = now)))
        assertEquals(1, due(slot(validUntilMs = now + 1)))
    }

    @Test
    fun dueSlotsComeMostCertainFirstOncePerRouteAndDirection() {
        val due = SmartRouteReminderRules.dueSlots(
            plan(
                slot(routeKey = 1, confidence = 0.6),
                slot(routeKey = 2, confidence = 0.9),
                slot(routeKey = 2, confidence = 0.7),
                slot(routeKey = 2, pathId = 1, confidence = 0.8),
            ),
            "khh",
            at(8, 7, 40),
            taipei,
        )

        assertEquals(
            listOf(2 to 0, 2 to 1, 1 to 0),
            due.map { it.routeKey to it.pathId },
        )
        assertEquals(0.9, due.first().confidence, 1e-9)
    }

    @Test
    fun aPlanWithNothingLeftToFireIsNotLive() {
        val now = at(8, 7, 40)

        assertTrue(SmartRouteReminderRules.hasLiveSlots(plan(slot()), now))
        assertFalse(SmartRouteReminderRules.hasLiveSlots(plan(slot(validUntilMs = now)), now))
        assertFalse(SmartRouteReminderRules.hasLiveSlots(plan(), now))
    }

    // --- holding a reminder back --------------------------------------------

    @Test
    fun aRouteAlreadyLookedAtForThisWindowIsNotRemindedAbout() {
        // Window opens 07:10; anything from 06:40 on counts as having looked.
        val now = at(8, 7, 40)
        fun seen(lastActivityAtMs: Long) = SmartRouteReminderRules.wasSeenForWindow(
            slot(lastActivityAtMs = lastActivityAtMs),
            now,
            nowMinute = 220,
        )

        assertFalse(seen(at(7, 7, 40)))
        assertFalse(seen(at(8, 6, 39)))
        assertTrue(seen(at(8, 6, 40)))
        assertTrue(seen(at(8, 7, 30)))
    }

    @Test
    fun remindersKeepApartAndStopAfterSixInADay() {
        val now = at(8, 7, 40)
        val today = 2026098L
        val twentyMinutes = 20 * 60 * 1000L

        assertTrue(SmartRouteReminderRules.mayRemind(SmartReminderHistory(), now, today))
        assertFalse(
            SmartRouteReminderRules.mayRemind(
                SmartReminderHistory(lastAnyMs = now - twentyMinutes + 1),
                now,
                today,
            ),
        )
        assertTrue(
            SmartRouteReminderRules.mayRemind(
                SmartReminderHistory(lastAnyMs = now - twentyMinutes),
                now,
                today,
            ),
        )
        assertFalse(
            SmartRouteReminderRules.mayRemind(
                SmartReminderHistory(countDay = today, countThatDay = 6),
                now,
                today,
            ),
        )
        assertTrue(
            SmartRouteReminderRules.mayRemind(
                SmartReminderHistory(countDay = today, countThatDay = 5),
                now,
                today,
            ),
        )
        // Yesterday's count does not carry over.
        assertTrue(
            SmartRouteReminderRules.mayRemind(
                SmartReminderHistory(countDay = today - 1, countThatDay = 6),
                now,
                today,
            ),
        )
    }

    @Test
    fun aReminderIsCountedAgainstItsDay() {
        val now = at(8, 7, 40)

        assertEquals(
            SmartReminderHistory(lastAnyMs = now, countDay = 7L, countThatDay = 3),
            SmartRouteReminderRules.afterReminder(
                SmartReminderHistory(lastAnyMs = 1L, countDay = 7L, countThatDay = 2),
                now,
                today = 7L,
            ),
        )
        assertEquals(
            SmartReminderHistory(lastAnyMs = now, countDay = 8L, countThatDay = 1),
            SmartRouteReminderRules.afterReminder(
                SmartReminderHistory(lastAnyMs = 1L, countDay = 7L, countThatDay = 6),
                now,
                today = 8L,
            ),
        )
    }

    @Test
    fun aRouteIsRemindedAboutOncePerWindow() {
        val now = at(8, 7, 40)
        val threeHours = 3 * 60 * 60 * 1000L

        assertTrue(SmartRouteReminderRules.mayRemindRoute(0L, now))
        assertFalse(SmartRouteReminderRules.mayRemindRoute(now - threeHours + 1, now))
        assertTrue(SmartRouteReminderRules.mayRemindRoute(now - threeHours, now))
    }

    // --- the log of what was shown ------------------------------------------

    @Test
    fun writesTheLogTheFlutterSideReads() {
        // The same file SmartRoutePlanner's test reads reminders from.
        val slots = SmartRouteReminderRules.parsePlan(sharedFixture().readText())!!.slots
        val firstShown = 1775604360000L
        val secondShown = 1775901000000L

        val log = SmartRouteReminderRules.appendToReminderLog(
            SmartRouteReminderRules.appendToReminderLog(null, slots.first(), firstShown),
            slots.last(),
            secondShown,
        )

        assertEquals(
            Json.parseToJsonElement(sharedFixture("smart_route_reminder_log_v1.json").readText()),
            Json.parseToJsonElement(log),
        )
        assertEquals(
            listOf(
                SmartReminderLogEntry("khh", 101, 0, firstShown, peakMinute = 220),
                SmartReminderLogEntry("khh", 202, 1, secondShown, peakMinute = 840),
            ),
            SmartRouteReminderRules.parseReminderLog(log),
        )
    }

    @Test
    fun theLogForgetsWhatTheHabitModelNoLongerLooksAt() {
        val now = at(8, 7, 40)
        val eightWeeks = 56L * 24 * 60 * 60 * 1000
        fun shownAt(vararg times: Long) = times.fold(null as String?) { log, time ->
            SmartRouteReminderRules.appendToReminderLog(log, slot(), time)
        }

        val log = SmartRouteReminderRules.appendToReminderLog(
            shownAt(now - eightWeeks, now - eightWeeks + 1, now - 1),
            slot(routeKey = 7),
            now,
        )

        assertEquals(
            listOf(now - eightWeeks + 1 to 101, now - 1 to 101, now to 7),
            SmartRouteReminderRules.parseReminderLog(log).map { it.atMs to it.routeKey },
        )
    }

    @Test
    fun theLogKeepsOnlyItsNewestEntries() {
        val now = at(8, 7, 40)
        var log: String? = null
        repeat(SmartRouteReminderRules.REMINDER_LOG_MAX_ENTRIES + 3) { index ->
            log = SmartRouteReminderRules.appendToReminderLog(log, slot(), now + index)
        }

        val entries = SmartRouteReminderRules.parseReminderLog(log)
        assertEquals(SmartRouteReminderRules.REMINDER_LOG_MAX_ENTRIES, entries.size)
        assertEquals(now + 3, entries.first().atMs)
        assertEquals(
            now + SmartRouteReminderRules.REMINDER_LOG_MAX_ENTRIES + 2,
            entries.last().atMs,
        )
    }

    @Test
    fun aLogThatCannotBeReadIsStartedAgainNotFailedOn() {
        val now = at(8, 7, 40)

        assertTrue(SmartRouteReminderRules.parseReminderLog(null).isEmpty())
        assertTrue(SmartRouteReminderRules.parseReminderLog(" ").isEmpty())
        assertTrue(SmartRouteReminderRules.parseReminderLog("[{").isEmpty())
        assertTrue(SmartRouteReminderRules.parseReminderLog("""{"atMs": 1}""").isEmpty())
        assertEquals(
            listOf(now),
            SmartRouteReminderRules.parseReminderLog(
                SmartRouteReminderRules.appendToReminderLog("[{", slot(), now),
            ).map { it.atMs },
        )
    }

    @Test
    fun oneUnreadableEntryDoesNotCostTheLogItsOthers() {
        val now = at(8, 7, 40)
        val log = """
            [
              {"provider": "khh", "routeKey": 101, "pathId": 0, "atMs": ${now - 2}},
              {"provider": "khh", "routeKey": "one hundred", "pathId": 0, "atMs": ${now - 1}},
              "not an entry",
              {"provider": "khh", "routeKey": 101, "pathId": 0, "atMs": $now, "peakMinute": 220, "later": true}
            ]
        """.trimIndent()

        assertEquals(
            listOf(
                // Written before the log said what a reminder was for.
                SmartReminderLogEntry("khh", 101, 0, now - 2, peakMinute = null),
                SmartReminderLogEntry("khh", 101, 0, now, peakMinute = 220),
            ),
            SmartRouteReminderRules.parseReminderLog(log),
        )
    }

    // --- which stop ---------------------------------------------------------

    @Test
    fun theUsualStopCanHaveANonNumericProviderId() {
        val alphanumeric = stop("101-11009")
        // Flutter stores the hash for a non-numeric id; the feed uses the text.
        assertEquals(
            alphanumeric,
            SmartRouteReminderRules.findUsualStop(slot(stopId = 64427917L), listOf(alphanumeric)),
        )
        assertNull(SmartRouteReminderRules.findUsualStop(slot(stopId = 0L), listOf(stop(""))))
    }

    @Test
    fun theUsualStopIsFoundByItsFullWidthIdOnTheSlotsDirection() {
        val stops = listOf(
            stop("18464"),
            stop("100100128221", name = "常用站"),
            stop("100100128221", pathId = 1, name = "對向"),
        )

        assertEquals(
            "常用站",
            SmartRouteReminderRules.findUsualStop(slot(), stops)?.stopName,
        )
        assertNull(SmartRouteReminderRules.findUsualStop(slot(stopId = null), stops))
        assertNull(SmartRouteReminderRules.findUsualStop(slot(stopId = 999L), stops))
        // 100100128221 and 1315880413 share their low 32 bits; they are not
        // the same stop.
        assertNull(SmartRouteReminderRules.findUsualStop(slot(stopId = 1315880413L), stops))
    }

    @Test
    fun theUsualStopIsWatchedWithoutAnyLocation() {
        val usual = stop("1", name = "常用站")

        val choice = SmartRouteReminderRules.chooseStop(
            usualStop = usual,
            usualDistanceMeters = null,
            nearestStop = null,
            nearestDistanceMeters = null,
        )

        assertEquals(usual, choice?.stop)
        assertNull(choice?.distanceMeters)
    }

    @Test
    fun theUsualStopIsKeptWhileItIsInReach() {
        val usual = stop("1", name = "常用站")
        val nearer = stop("2", name = "較近")

        val choice = SmartRouteReminderRules.chooseStop(
            usualStop = usual,
            usualDistanceMeters = 1000.0,
            nearestStop = nearer,
            nearestDistanceMeters = 50.0,
        )

        assertEquals(usual, choice?.stop)
        assertEquals(1000.0, choice!!.distanceMeters!!, 1e-9)
    }

    @Test
    fun farFromTheUsualStopTheNearestStandsInIfItIsClose() {
        val usual = stop("1", name = "常用站")
        val nearest = stop("2", name = "最近")

        val close = SmartRouteReminderRules.chooseStop(usual, 1000.1, nearest, 800.0)
        val tooFar = SmartRouteReminderRules.chooseStop(usual, 5000.0, nearest, 800.1)

        assertEquals(nearest, close?.stop)
        assertEquals(800.0, close!!.distanceMeters!!, 1e-9)
        assertNull(tooFar)
    }

    @Test
    fun withNoUsualStopOnlyANearbyOneWillDo() {
        val nearest = stop("2", name = "最近")

        assertEquals(
            nearest,
            SmartRouteReminderRules.chooseStop(null, null, nearest, 300.0)?.stop,
        )
        assertNull(SmartRouteReminderRules.chooseStop(null, null, nearest, 900.0))
        assertNull(SmartRouteReminderRules.chooseStop(null, null, null, null))
    }

    // --- the live feed ------------------------------------------------------

    private val feedTime = at(8, 7, 30)

    private fun feed(updatedAtSeconds: Long = feedTime / 1000 - 15) = """
        {"routeid": "KHH101", "updated_at": $updatedAtSeconds, "stale": false, "paths": [
          {"pathid": 0, "name": "往甲", "stops": [
            {"stopid": "18464", "eta": null, "message": "未發車", "updated_at": $updatedAtSeconds,
             "buses": [], "etas": []},
            {"stopid": "100100128221", "eta": 480, "message": null,
             "updated_at": $updatedAtSeconds, "buses": [],
             "etas": [{"eta": 480, "plate": "KKA-0001"},
                      {"eta": 900, "message": "未發車"},
                      {"eta": 1260, "plate": "KKA-0002", "message": ""},
                      {"eta": null, "message": "末班駛離"}]},
            {"stopid": 18470, "eta": 95, "message": "即將進站", "updated_at": $updatedAtSeconds,
             "buses": [], "etas": [{"eta": 95}]}
          ]},
          {"pathid": 1, "name": "往乙", "stops": [
            {"stopid": "100100128221", "eta": 60, "message": null,
             "updated_at": $updatedAtSeconds, "buses": [], "etas": []},
            {"stopid": "20001", "eta": 300, "message": null, "updated_at": $updatedAtSeconds}
          ]}
        ]}
    """.trimIndent()

    @Test
    fun readsAStopsArrivalsFromTheFeed() {
        val stop = SmartRouteReminderRules.parseLiveStop(feed(), 0, "100100128221", feedTime)

        assertEquals(480, stop?.sec)
        assertNull(stop?.msg)
        // The entries that carry a status instead of a time are left out.
        assertEquals(listOf(480, 1260), stop?.arrivals)
    }

    @Test
    fun readsAStopOnlyFromItsOwnDirection() {
        // The same id is on both directions; the bus a minute away is the
        // one going the other way.
        assertEquals(
            60,
            SmartRouteReminderRules.parseLiveStop(feed(), 1, "100100128221", feedTime)?.sec,
        )
        assertNull(SmartRouteReminderRules.parseLiveStop(feed(), 0, "20001", feedTime))
        assertNull(SmartRouteReminderRules.parseLiveStop(feed(), 2, "100100128221", feedTime))
    }

    @Test
    fun readsStatusMessagesAndNumericStopIds() {
        val notDeparted = SmartRouteReminderRules.parseLiveStop(feed(), 0, "18464", feedTime)
        val arriving = SmartRouteReminderRules.parseLiveStop(feed(), 0, "18470", feedTime)

        assertNull(notDeparted?.sec)
        assertEquals("未發車", notDeparted?.msg)
        assertEquals(emptyList<Int>(), notDeparted?.arrivals)
        assertEquals(95, arriving?.sec)
        assertEquals("即將進站", arriving?.msg)
    }

    @Test
    fun anEstimateTooOldToActOnIsNoEstimate() {
        val fiveMinutes = 5 * 60L
        fun read(updatedAtSeconds: Long) = SmartRouteReminderRules.parseLiveStop(
            feed(updatedAtSeconds),
            0,
            "100100128221",
            feedTime,
        )

        assertNotNull(read(feedTime / 1000 - fiveMinutes))
        assertNull(read(feedTime / 1000 - fiveMinutes - 1))
        // A device clock a little behind the server's is not a stale feed.
        assertNotNull(read(feedTime / 1000 + 120))
    }

    @Test
    fun aResponseThatIsNotAFeedYieldsNothing() {
        assertNull(SmartRouteReminderRules.parseLiveStop("", 0, "1", feedTime))
        assertNull(SmartRouteReminderRules.parseLiveStop("[]", 0, "1", feedTime))
        assertNull(SmartRouteReminderRules.parseLiveStop("{}", 0, "1", feedTime))
        assertNull(SmartRouteReminderRules.parseLiveStop("""{"paths": 3}""", 0, "1", feedTime))
    }

    // --- whether there is a bus worth mentioning ----------------------------

    @Test
    fun remindsAboutABusThatCanStillBeCaught() {
        val decision = SmartRouteReminderRules.decide(
            SmartLiveStop(sec = 480, msg = null, arrivals = listOf(480, 1260)),
            distanceMeters = null,
        )

        assertEquals(SmartEtaDecision(etaSeconds = 480, followingEtaSeconds = 1260), decision)
    }

    @Test
    fun aBusTooCloseToCatchGivesWayToTheOneBehindIt() {
        val live = SmartLiveStop(sec = 179, msg = null, arrivals = listOf(179, 900))

        assertEquals(
            SmartEtaDecision(etaSeconds = 900, followingEtaSeconds = null),
            SmartRouteReminderRules.decide(live, distanceMeters = null),
        )
        assertEquals(
            180,
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 180, msg = null),
                distanceMeters = null,
            )?.etaSeconds,
        )
    }

    @Test
    fun theWalkToTheStopDecidesWhichBusIsCatchable() {
        // 600 m at a metre a second, plus a minute to spare: eleven minutes.
        val live = SmartLiveStop(sec = 480, msg = null, arrivals = listOf(480, 659, 660, 1400))

        assertEquals(660, SmartRouteReminderRules.walkingSeconds(600.0))
        assertEquals(
            SmartEtaDecision(etaSeconds = 660, followingEtaSeconds = 1400),
            SmartRouteReminderRules.decide(live, distanceMeters = 600.0),
        )
        assertEquals(480, SmartRouteReminderRules.decide(live, distanceMeters = 100.0)?.etaSeconds)
    }

    @Test
    fun aBusStillFarOffIsLeftForALaterCheck() {
        assertEquals(
            1500,
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 1500, msg = null),
                distanceMeters = null,
            )?.etaSeconds,
        )
        assertNull(
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 1501, msg = null),
                distanceMeters = null,
            ),
        )
        // Nor is a far bus mentioned just because a near one cannot be caught.
        assertNull(
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 60, msg = null, arrivals = listOf(60, 1800)),
                distanceMeters = null,
            ),
        )
    }

    @Test
    fun aStopReportingAStatusIsNotAnArrival() {
        // The old rule sent a reminder for any message at all, 未發車 included.
        listOf("未發車", "交管不停靠", "今日未營運", "末班駛離").forEach { message ->
            assertNull(
                message,
                SmartRouteReminderRules.decide(
                    SmartLiveStop(sec = null, msg = message),
                    distanceMeters = null,
                ),
            )
        }
        // The top-level time is not trusted when a status comes with it, but
        // a timed bus listed behind it still counts.
        assertNull(
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 600, msg = "未發車"),
                distanceMeters = null,
            ),
        )
        assertEquals(
            600,
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 30, msg = "進站中", arrivals = listOf(30, 600)),
                distanceMeters = null,
            )?.etaSeconds,
        )
    }

    @Test
    fun theLastBusHavingGoneEndsIt() {
        assertNull(
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = 600, msg = "末班車：已過。", arrivals = listOf(600)),
                distanceMeters = null,
            ),
        )
    }

    @Test
    fun withNoTimedArrivalThereIsNothingToSay() {
        assertNull(
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = null, msg = null),
                distanceMeters = null,
            ),
        )
        assertNull(
            SmartRouteReminderRules.decide(
                SmartLiveStop(sec = -1, msg = null, arrivals = listOf(-5)),
                distanceMeters = null,
            ),
        )
    }

    // --- what the reminder says ---------------------------------------------

    @Test
    fun theReminderGivesTheArrivalAsAClockTime() {
        val text = SmartRouteReminderRules.buildText(
            routeName = "307",
            pathName = "往市政府",
            stopName = "捷運國父紀念館站",
            decision = SmartEtaDecision(etaSeconds = 480, followingEtaSeconds = 1260),
            distanceMeters = 350.0,
            slot = slot(peakMinute = 218),
            dayStartHour = 4,
            nowMs = at(8, 7, 30),
            zone = taipei,
        )

        assertEquals("307 約 8 分後到站", text.title)
        assertEquals("捷運國父紀念館站 · 預計 07:38 到站", text.text)
        assertEquals(
            "捷運國父紀念館站 預計 07:38 到站，下一班約 21 分後。" +
                "方向：往市政府。距離你約 350m。你常在 07:40 左右查看這條路線。",
            text.bigText,
        )
    }

    @Test
    fun theReminderLeavesOutWhatItDoesNotKnow() {
        val text = SmartRouteReminderRules.buildText(
            routeName = " ",
            pathName = null,
            stopName = "常用站",
            decision = SmartEtaDecision(etaSeconds = 200, followingEtaSeconds = null),
            distanceMeters = null,
            // 00:20, twenty hours and twenty minutes into the service day.
            slot = slot(peakMinute = 1220),
            dayStartHour = 4,
            nowMs = at(8, 23, 58),
            zone = taipei,
        )

        assertEquals("路線 約 3 分後到站", text.title)
        assertEquals("常用站 · 預計 00:01 到站", text.text)
        assertEquals("常用站 預計 00:01 到站。你常在 00:20 左右查看這條路線。", text.bigText)
    }

    @Test
    fun aReminderSaysSoWhenItsHabitIsAboutToLapse() {
        val now = at(8, 7, 30)
        val threeDays = 3L * 24 * 60 * 60 * 1000
        fun bigText(validUntilMs: Long) = SmartRouteReminderRules.buildText(
            routeName = "307",
            pathName = null,
            stopName = "常用站",
            decision = SmartEtaDecision(etaSeconds = 480, followingEtaSeconds = null),
            distanceMeters = null,
            slot = slot(validUntilMs = validUntilMs),
            dayStartHour = 4,
            nowMs = now,
            zone = taipei,
        ).bigText
        val usual = "常用站 預計 07:38 到站。你常在 07:40 左右查看這條路線。"
        val notice = "\n已有一段時間沒有開啟這條路線，提醒即將暫停；點這則通知查看路線即可繼續收到。"

        // Three days is when it starts being said, and not a moment sooner.
        assertEquals(usual, bigText(now + threeDays + 1))
        assertEquals(usual + notice, bigText(now + threeDays))
        assertEquals(usual + notice, bigText(now + 1))
        assertFalse(SmartRouteReminderRules.isAboutToLapse(slot(), now))
        assertTrue(
            SmartRouteReminderRules.isAboutToLapse(slot(validUntilMs = now + threeDays), now),
        )
    }

    @Test
    fun distancesReadTheSameInEveryLocale() {
        assertEquals("999m", SmartRouteReminderRules.formatDistance(999.9))
        assertEquals("1.0km", SmartRouteReminderRules.formatDistance(1000.0))
        assertEquals("2.5km", SmartRouteReminderRules.formatDistance(2540.0))
    }

    @Test
    fun aReminderOutlivesItsBusByThreeMinutes() {
        assertEquals(
            (480 + 180) * 1000L,
            SmartRouteReminderRules.timeoutMs(SmartEtaDecision(480, null)),
        )
    }

    /**
     * A file under `test/fixtures` at the repository root, shared with the
     * Dart tests so that a change to what one side writes cannot pass without
     * the other side reading it.
     */
    private fun sharedFixture(name: String = "smart_route_plan_v1.json"): File {
        var directory: File? = File("").absoluteFile
        while (directory != null) {
            val candidate = File(directory, "test/fixtures/$name")
            if (candidate.isFile) {
                return candidate
            }
            directory = directory.parentFile
        }
        error("test/fixtures/$name not found above ${File("").absolutePath}")
    }
}
