package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** What the worker keeps about the reminders it has shown, and for whom. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class SmartRouteReminderStoreTest {
    private lateinit var context: Context

    private val slot = SmartPlanSlot(
        provider = "khh",
        routeKey = 101,
        routeId = "KHH101",
        pathId = 0,
        routeName = "307",
        weekday = 3,
        startMinute = 190,
        endMinute = 250,
        peakMinute = 220,
        validUntilMs = Long.MAX_VALUE,
    )
    private val shownAt = 1775604360000L
    private val history = SmartReminderHistory(
        lastAnyMs = shownAt,
        countDay = 2026098L,
        countThatDay = 1,
    )

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
    }

    private fun loggedReminders() = SmartRouteReminderRules.parseReminderLog(
        SmartRouteNotificationSupport.loadReminderLog(context),
    )

    @Test
    fun nothingHasBeenShownToBeginWith() {
        assertEquals("[]", SmartRouteNotificationSupport.loadReminderLog(context))
        assertEquals(SmartReminderHistory(), SmartRouteNotificationSupport.loadHistory(context))
        assertEquals(0L, SmartRouteNotificationSupport.loadLastReminderForRoute(context, slot))
    }

    @Test
    fun aReminderIsRememberedForTheNextCheckAndForTheFlutterSide() {
        SmartRouteNotificationSupport.saveReminder(context, slot, history, shownAt)

        // For the next check: what holds a reminder back.
        assertEquals(history, SmartRouteNotificationSupport.loadHistory(context))
        assertEquals(
            shownAt,
            SmartRouteNotificationSupport.loadLastReminderForRoute(context, slot),
        )
        // The other direction of the same route is another habit.
        assertEquals(
            0L,
            SmartRouteNotificationSupport.loadLastReminderForRoute(context, slot.copy(pathId = 1)),
        )
        // For the Flutter side: that it was shown, and what time it was for.
        assertEquals(
            listOf(SmartReminderLogEntry("khh", 101, 0, shownAt, peakMinute = 220)),
            loggedReminders(),
        )
    }

    @Test
    fun eachReminderIsAddedToTheLog() {
        val evening = slot.copy(routeKey = 202, pathId = 1, peakMinute = 840)
        val later = shownAt + 10 * 60 * 60 * 1000L

        SmartRouteNotificationSupport.saveReminder(context, slot, history, shownAt)
        SmartRouteNotificationSupport.saveReminder(
            context,
            evening,
            history.copy(lastAnyMs = later, countThatDay = 2),
            later,
        )

        assertEquals(
            listOf(
                SmartReminderLogEntry("khh", 101, 0, shownAt, peakMinute = 220),
                SmartReminderLogEntry("khh", 202, 1, later, peakMinute = 840),
            ),
            loggedReminders(),
        )
        assertEquals(2, SmartRouteNotificationSupport.loadHistory(context).countThatDay)
    }

    @Test
    fun forgettingLeavesNothingBehind() {
        SmartRouteNotificationSupport.saveReminder(context, slot, history, shownAt)

        SmartRouteNotificationSupport.forgetReminders(context)

        assertEquals("[]", SmartRouteNotificationSupport.loadReminderLog(context))
        assertEquals(SmartReminderHistory(), SmartRouteNotificationSupport.loadHistory(context))
        assertEquals(0L, SmartRouteNotificationSupport.loadLastReminderForRoute(context, slot))
    }
}
