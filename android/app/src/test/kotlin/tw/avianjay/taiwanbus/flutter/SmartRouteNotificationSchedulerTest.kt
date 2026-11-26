package tw.avianjay.taiwanbus.flutter

import android.content.Context
import androidx.work.WorkInfo
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** Whether the background check is scheduled, and who may stop it. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = YABusApplication::class)
class SmartRouteNotificationSchedulerTest {
    private lateinit var context: Context

    private val liveSlot = SmartPlanSlot(
        provider = "khh",
        routeKey = 101,
        routeId = "KHH101",
        pathId = 0,
        weekday = 3,
        startMinute = 190,
        endMinute = 250,
        peakMinute = 220,
        validUntilMs = Long.MAX_VALUE,
    )

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
    }

    private fun writePlan(vararg slots: SmartPlanSlot) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString(
                "flutter.smart_route_plan",
                Json.encodeToString(SmartRoutePlan(version = 1, slots = slots.toList())),
            )
            .commit()
    }

    /** Queued after whatever was asked of WorkManager before it, so it sees that done. */
    private fun work(): List<WorkInfo> = WorkManager.getInstance(context)
        .getWorkInfosForUniqueWork(SmartRouteNotificationScheduler.WORK_NAME)
        .get(10, TimeUnit.SECONDS)

    private fun isScheduled() = work().let { infos ->
        infos.isNotEmpty() && infos.any { !it.state.isFinished }
    }

    @Test
    fun aPlanWithSomethingLeftToFireIsScheduledAndNothingElse() {
        writePlan(liveSlot)
        SmartRouteNotificationScheduler.sync(context, enabled = true)
        assertTrue(isScheduled())

        SmartRouteNotificationScheduler.sync(context, enabled = false)
        assertTrue(!isScheduled())

        writePlan(liveSlot.copy(validUntilMs = 1L))
        SmartRouteNotificationScheduler.sync(context, enabled = true)
        assertTrue(!isScheduled())
    }

    @Test
    fun aCheckThatReadAnOldPlanDoesNotStopTheNewOne() {
        // A check read a plan with nothing left in it. Before it got round
        // to stopping itself, the app wrote a new plan and rescheduled.
        writePlan(liveSlot)
        SmartRouteNotificationScheduler.sync(context, enabled = true)

        SmartRouteNotificationScheduler.cancelIfNothingLive(context)

        assertTrue(isScheduled())

        // With the plan really empty, it does stop.
        writePlan(liveSlot.copy(validUntilMs = 1L))
        SmartRouteNotificationScheduler.cancelIfNothingLive(context)
        assertTrue(!isScheduled())
    }
}
