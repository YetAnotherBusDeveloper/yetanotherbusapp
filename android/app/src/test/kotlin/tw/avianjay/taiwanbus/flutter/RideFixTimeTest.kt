package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.location.Location
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A fix handed to the ride detector has to carry when it was really measured.
 *
 * It used to be aged by subtracting `Location.time` (Unix epoch) from
 * `SystemClock.elapsedRealtime()` (time since boot). That difference is hugely
 * negative and was clamped to zero, so every fix — including a position cached
 * minutes earlier — reached the detector stamped "now".
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class RideFixTimeTest {
    private val nowWallMs = 1_700_000_000_000L
    private val nowElapsedNanos = TimeUnit.HOURS.toNanos(3)

    @Test
    fun aCachedFixIsPlacedItsRealAgeInThePast() {
        val cached = Location("fused").apply {
            elapsedRealtimeNanos = nowElapsedNanos - TimeUnit.MINUTES.toNanos(5)
            // A provider's clock need not agree with the device's: the age has
            // to come from the monotonic stamp, not from this.
            time = nowWallMs + TimeUnit.DAYS.toMillis(1)
        }

        assertEquals(nowWallMs - 300_000L, rideFixTimestampMs(cached, nowWallMs, nowElapsedNanos))
    }

    @Test
    fun aFixStampedAheadOfTheClockCountsAsCurrent() {
        val ahead = Location("fused").apply {
            elapsedRealtimeNanos = nowElapsedNanos + TimeUnit.SECONDS.toNanos(2)
        }

        assertEquals(nowWallMs, rideFixTimestampMs(ahead, nowWallMs, nowElapsedNanos))
    }

    @Test
    fun aHandBuiltPositionIsAgedByItsOwnTime() {
        // The session's starting position is built from what Flutter sent, and
        // has no monotonic stamp; Flutter says when it was measured instead.
        val seed = Location("trip_monitor_session").apply {
            time = nowWallMs - 180_000L
        }

        assertEquals(nowWallMs - 180_000L, rideFixTimestampMs(seed, nowWallMs, nowElapsedNanos))
    }

    @Test
    fun aHandBuiltPositionWithNoUsableTimeCountsAsCurrent() {
        val untimed = Location("trip_monitor_session")
        val fromTheFuture = Location("trip_monitor_session").apply {
            time = nowWallMs + 60_000L
        }

        assertEquals(nowWallMs, rideFixTimestampMs(untimed, nowWallMs, nowElapsedNanos))
        assertEquals(nowWallMs, rideFixTimestampMs(fromTheFuture, nowWallMs, nowElapsedNanos))
    }
}
