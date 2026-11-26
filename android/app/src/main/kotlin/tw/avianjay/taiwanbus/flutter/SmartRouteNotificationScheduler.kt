package tw.avianjay.taiwanbus.flutter

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object SmartRouteNotificationScheduler {
    /** The name the work is scheduled under. */
    internal const val WORK_NAME = "smart_route_notification_refresh"

    /**
     * Held while the plan is read and the work scheduled or cancelled to
     * match it, by the app and by the background check alike.
     *
     * The app writes a plan and only then asks for the work to be synced, so
     * a decision taken under this lock from a plan that has since been
     * replaced is always followed by one taken from the new plan, and
     * WorkManager carries both out in the order they were asked for. Without
     * it, a check that read the old plan could cancel the work after the app
     * had rescheduled it for the new one.
     */
    private val lock = Any()

    /**
     * Runs the background check only while there is something for it to do:
     * the setting is on and the plan still holds a habit that has not lapsed.
     */
    fun sync(context: Context, enabled: Boolean) {
        synchronized(lock) {
            val plan = if (enabled) SmartRouteNotificationSupport.loadPlan(context) else null
            if (plan == null ||
                !SmartRouteReminderRules.hasLiveSlots(plan, System.currentTimeMillis())
            ) {
                cancelUnlocked(context)
                return
            }

            val request = PeriodicWorkRequestBuilder<SmartRouteNotificationWorker>(
                15,
                TimeUnit.MINUTES,
            ).setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            ).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
        }
    }

    /**
     * Stops the background check if the plan as it is now has nothing left
     * that could fire — not the plan the caller read some time ago, which the
     * app may have replaced since with one that does.
     */
    fun cancelIfNothingLive(context: Context) {
        synchronized(lock) {
            val plan = SmartRouteNotificationSupport.loadPlan(context)
            if (plan == null ||
                !SmartRouteReminderRules.hasLiveSlots(plan, System.currentTimeMillis())
            ) {
                cancelUnlocked(context)
            }
        }
    }

    private fun cancelUnlocked(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}
