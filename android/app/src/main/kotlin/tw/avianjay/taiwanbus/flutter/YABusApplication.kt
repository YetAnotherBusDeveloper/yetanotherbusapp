package tw.avianjay.taiwanbus.flutter

import android.app.Application
import androidx.work.Configuration

/** Supplies WorkManager configuration on demand, also in background-only starts. */
class YABusApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()
}
