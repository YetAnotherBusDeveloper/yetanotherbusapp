package tw.avianjay.taiwanbus.flutter

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot

internal data class RideProjection(
    val alongMeters: Double,
    val crossTrackMeters: Double,
    val segmentIndex: Int,
)

/**
 * The stop sequence as a polyline in a local equirectangular plane, with
 * cumulative distance, so that the user and every bus reduce to one comparable
 * number: metres travelled from the first stop.
 */
internal class RideRouteLine(private val stops: List<TrackingStop>) {
    private val originLat = stops.first().lat
    private val originLon = stops.first().lon
    private val metersPerDegreeLon = EARTH_RADIUS_METERS * cos(originLat * PI / 180.0) * PI / 180.0
    private val metersPerDegreeLat = EARTH_RADIUS_METERS * PI / 180.0
    private val xs = DoubleArray(stops.size) { (stops[it].lon - originLon) * metersPerDegreeLon }
    private val ys = DoubleArray(stops.size) { (stops[it].lat - originLat) * metersPerDegreeLat }
    private val cumulativeMeters = DoubleArray(stops.size).also { cumulative ->
        for (index in 1 until stops.size) {
            cumulative[index] = cumulative[index - 1] +
                hypot(xs[index] - xs[index - 1], ys[index] - ys[index - 1])
        }
    }

    /** Metres from the first stop to [stopIndex]. */
    fun alongOfStop(stopIndex: Int): Double = cumulativeMeters[stopIndex.coerceIn(0, stops.size - 1)]

    fun segmentLengthMeters(segmentIndex: Int): Double {
        val index = segmentIndex.coerceIn(0, (stops.size - 2).coerceAtLeast(0))
        return if (stops.size < 2) 0.0 else cumulativeMeters[index + 1] - cumulativeMeters[index]
    }

    fun metersBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        return hypot((lon2 - lon1) * metersPerDegreeLon, (lat2 - lat1) * metersPerDegreeLat)
    }

    fun metersToStop(latitude: Double, longitude: Double, stopIndex: Int): Double {
        val stop = stops[stopIndex.coerceIn(0, stops.size - 1)]
        return metersBetween(latitude, longitude, stop.lat, stop.lon)
    }

    /**
     * Projects a fix onto the polyline.
     *
     * [hintMeters] disambiguates routes that run along the same street twice
     * (loops, out-and-back sections): among the segments about as close as the
     * closest one, the one nearest the previous along-route position wins.
     */
    fun project(latitude: Double, longitude: Double, hintMeters: Double?): RideProjection {
        val segmentCount = stops.size - 1
        if (segmentCount <= 0) {
            return RideProjection(0.0, metersToStop(latitude, longitude, 0), 0)
        }
        val px = (longitude - originLon) * metersPerDegreeLon
        val py = (latitude - originLat) * metersPerDegreeLat
        val distances = DoubleArray(segmentCount)
        val alongs = DoubleArray(segmentCount)
        var closest = 0
        for (index in 0 until segmentCount) {
            val vx = xs[index + 1] - xs[index]
            val vy = ys[index + 1] - ys[index]
            val lengthSquared = vx * vx + vy * vy
            val t = if (lengthSquared <= 1e-9) {
                0.0
            } else {
                (((px - xs[index]) * vx + (py - ys[index]) * vy) / lengthSquared).coerceIn(0.0, 1.0)
            }
            distances[index] = hypot(px - (xs[index] + t * vx), py - (ys[index] + t * vy))
            alongs[index] = cumulativeMeters[index] +
                t * (cumulativeMeters[index + 1] - cumulativeMeters[index])
            if (distances[index] < distances[closest]) {
                closest = index
            }
        }
        var chosen = closest
        if (hintMeters != null) {
            for (index in 0 until segmentCount) {
                if (distances[index] <= distances[closest] + HINT_SLACK_METERS &&
                    abs(alongs[index] - hintMeters) < abs(alongs[chosen] - hintMeters)
                ) {
                    chosen = index
                }
            }
        }
        return RideProjection(alongs[chosen], distances[closest], chosen)
    }

    fun nearestStopIndex(alongMeters: Double): Int {
        var best = 0
        for (index in cumulativeMeters.indices) {
            if (abs(cumulativeMeters[index] - alongMeters) < abs(cumulativeMeters[best] - alongMeters)) {
                best = index
            }
        }
        return best
    }

    /**
     * The last stop reached at [alongMeters]. A vehicle pulling in counts as
     * having reached the stop, hence the tolerance. Unlike the nearest stop,
     * this only moves forward as the vehicle does, so "stops to go" counts down
     * at the stops themselves rather than midway between them.
     */
    fun stopIndexAt(alongMeters: Double): Int {
        var reached = 0
        for (index in cumulativeMeters.indices) {
            if (cumulativeMeters[index] <= alongMeters + STOP_REACHED_TOLERANCE_METERS) {
                reached = index
            }
        }
        return reached
    }

    private companion object {
        const val EARTH_RADIUS_METERS = 6_371_000.0
        const val HINT_SLACK_METERS = 60.0
        const val STOP_REACHED_TOLERANCE_METERS = 25.0
    }
}
