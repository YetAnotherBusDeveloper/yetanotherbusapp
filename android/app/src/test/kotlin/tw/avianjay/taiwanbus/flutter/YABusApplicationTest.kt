package tw.avianjay.taiwanbus.flutter

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.startup.AppInitializer
import androidx.startup.InitializationProvider
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkManagerInitializer
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = YABusApplication::class)
class YABusApplicationTest {
    @Test
    fun manifestRetainsStartupProviderWithoutEagerWorkManager() {
        val application = RuntimeEnvironment.getApplication()
        val provider = application.packageManager.getProviderInfo(
            ComponentName(application, InitializationProvider::class.java),
            PackageManager.GET_META_DATA,
        )
        assertFalse(provider.metaData.containsKey(WorkManagerInitializer::class.java.name))
        assertTrue(provider.metaData.containsKey("androidx.lifecycle.ProcessLifecycleInitializer"))
    }

    @Test
    fun backgroundOnlyProcessCanEnqueueAndCancelWorkOnDemand() {
        val application = RuntimeEnvironment.getApplication()
        assertFalse(AppInitializer.getInstance(application)
            .isEagerlyInitialized(WorkManagerInitializer::class.java))
        val manager = WorkManager.getInstance(application)
        assertSame(manager, WorkManager.getInstance(application))
        // No Flutter activity is created. A delay keeps this test worker idle.
        val request = PeriodicWorkRequestBuilder<StartupProbeWorker>(15, TimeUnit.MINUTES)
            .setInitialDelay(1, TimeUnit.DAYS)
            .build()
        manager.enqueueUniquePeriodicWork("startup-probe", ExistingPeriodicWorkPolicy.KEEP, request)
            .result.get(10, TimeUnit.SECONDS)
        assertTrue(manager.getWorkInfosForUniqueWork("startup-probe")
            .get(10, TimeUnit.SECONDS).isNotEmpty())
        manager.cancelUniqueWork("startup-probe").result.get(10, TimeUnit.SECONDS)
        assertTrue(manager.getWorkInfosForUniqueWork("startup-probe")
            .get(10, TimeUnit.SECONDS).all { it.state.isFinished })
    }
}

class StartupProbeWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result = Result.success()
}
