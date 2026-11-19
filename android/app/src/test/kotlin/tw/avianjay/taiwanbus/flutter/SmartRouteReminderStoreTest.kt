package tw.avianjay.taiwanbus.flutter

import android.Manifest
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import java.util.Calendar
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
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

    // --- sending one --------------------------------------------------------

    /** A Wednesday at 07:40 on this machine's clock: [slot] is due. */
    private val wednesdayMorning = Calendar.getInstance().apply {
        clear()
        set(2026, Calendar.APRIL, 8, 7, 40)
    }.timeInMillis

    private fun writePlan(vararg slots: SmartPlanSlot) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString(
                "flutter.smart_route_plan",
                Json.encodeToString(SmartRoutePlan(version = 1, slots = slots.toList())),
            )
            .commit()
    }

    private fun remind(read: SmartPlanSlot = slot): Boolean {
        val texts = mutableListOf<SmartPlanSlot>()
        return SmartRouteNotificationSupport.remind(
            context = context,
            slot = read,
            stop = SmartRouteStop(0, "100100128221", "常用站", 1, 120.3, 22.6),
            text = { current ->
                texts += current
                SmartReminderText("307 約 8 分後到站", current.routeName, current.routeName)
            },
            timeoutMs = 60_000L,
            history = history,
            nowMs = wednesdayMorning,
            checkedAtMs = wednesdayMorning,
        )
    }

    private fun posted() = shadowOf(
        context.getSystemService(NotificationManager::class.java),
    ).allNotifications

    private fun allowNotifications() {
        shadowOf(context as Application).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        SmartRouteNotificationSupport.ensureChannel(context)
    }

    @Test
    fun aReminderStillDueIsShownAndRemembered() {
        allowNotifications()
        writePlan(slot.copy(routeName = "307 新"))

        assertTrue(remind())

        // Shown as the plan has it now, not as it was first read.
        assertEquals("307 新", posted().single().extras.getString("android.text"))
        assertEquals(
            listOf(SmartReminderLogEntry("khh", 101, 0, wednesdayMorning, peakMinute = 220)),
            loggedReminders(),
        )
    }

    @Test
    fun aReminderThePlanNoLongerHasIsNeitherShownNorRemembered() {
        allowNotifications()
        // Read from a plan that has since been cleared, or rebuilt after the
        // route was opened.
        writePlan()
        assertFalse(remind())
        writePlan(slot.copy(lastActivityAtMs = wednesdayMorning - 60_000L))
        assertFalse(remind())

        assertTrue(posted().isEmpty())
        assertEquals("[]", SmartRouteNotificationSupport.loadReminderLog(context))
        assertEquals(SmartReminderHistory(), SmartRouteNotificationSupport.loadHistory(context))
    }

    @Test
    fun aReminderIsNotSentToARiderWhoHasTheAppOpen() {
        allowNotifications()
        writePlan(slot)
        AppRuntimeStateStore.setAppInForeground(context, true)

        assertFalse(remind())
        assertTrue(posted().isEmpty())
        assertEquals("[]", SmartRouteNotificationSupport.loadReminderLog(context))
    }

    @Test
    fun aReminderOnAChannelTurnedOffIsNotRemembered() {
        // Notifications are on for the app, but the rider turned this kind
        // off: the system would drop it, so nobody saw it.
        shadowOf(context as Application).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                SmartRouteNotificationSupport.CHANNEL_ID,
                "智慧推薦提醒",
                NotificationManager.IMPORTANCE_NONE,
            ),
        )
        writePlan(slot)

        assertFalse(SmartRouteNotificationSupport.canPostNotifications(context))
        assertFalse(remind())
        assertTrue(posted().isEmpty())
        assertEquals("[]", SmartRouteNotificationSupport.loadReminderLog(context))
        assertEquals(0L, SmartRouteNotificationSupport.loadLastReminderForRoute(context, slot))
    }
}
