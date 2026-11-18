package tw.avianjay.taiwanbus.flutter

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object SmartRouteNotificationScheduler {
    private const val WORK_NAME = "smart_route_notification_refresh"

    /**
     * Runs the background check only while there is something for it to do:
     * the setting is on and the plan still holds a habit that has not lapsed.
     */
    fun sync(context: Context, enabled: Boolean) {
        val plan = if (enabled) SmartRouteNotificationSupport.loadPlan(context) else null
        if (plan == null ||
            !SmartRouteReminderRules.hasLiveSlots(plan, System.currentTimeMillis())
        ) {
            cancel(context)
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

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}
