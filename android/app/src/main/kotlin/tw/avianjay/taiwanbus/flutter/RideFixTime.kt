package tw.avianjay.taiwanbus.flutter

import android.location.Location
import android.os.SystemClock

/**
 * When [location] was measured, on the wall clock the ride detector runs on.
 *
 * A fix's age is read off the monotonic clock, the only one a fix and "now" are
 * guaranteed to share: `Location.time` may come from the satellites, the
 * network or the system clock, and none of those has to agree with
 * `System.currentTimeMillis()`. Taking that age off the current wall-clock time
 * puts a fix cached five minutes ago five minutes in the past — where the
 * detector can see it is stale — however the device's clock happens to be set.
 *
 * A location with no monotonic stamp did not come from the platform (the
 * session's seed position is built by hand). Its own `time` is used when it has
 * a believable one, and it counts as current otherwise.
 */
internal fun rideFixTimestampMs(
    location: Location,
    nowWallMs: Long = System.currentTimeMillis(),
    nowElapsedNanos: Long = SystemClock.elapsedRealtimeNanos(),
): Long {
    val fixElapsedNanos = location.elapsedRealtimeNanos
    if (fixElapsedNanos > 0L) {
        val ageMs = ((nowElapsedNanos - fixElapsedNanos) / NANOS_PER_MILLI).coerceAtLeast(0L)
        return nowWallMs - ageMs
    }
    return location.time.takeIf { it in 1L..nowWallMs } ?: nowWallMs
}

private const val NANOS_PER_MILLI = 1_000_000L
