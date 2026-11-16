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
     * A route can come within a few metres of itself — a loop, a street used
     * out and back, the two legs of a hairpin — so the segment nearest a fix
     * is not always the one being travelled. [hintMeters], the previous
     * along-route position, settles it among the segments about as close as
     * the closest one. Each is costed by how far the fix is from it, plus a
     * share of how far along the route it would mean the fix had moved; and
     * moving back along the route costs four times as much as moving on, since
     * neither a bus nor its rider does that for long.
     *
     * Choosing simply the segment nearest the previous position held a
     * vehicle on the outbound leg of a hairpin once it had turned: the
     * outbound leg, 40 m away, was nearer where it had been than the leg it
     * was now exactly on, and each fix after that put it further back. Two
     * passes along the very same street, where distance says nothing, are
     * still told apart by which of them continues the journey.
     *
     * The distance returned is the one to the segment chosen, which is also
     * the segment [RideProjection.segmentIndex] names: callers hold the two
     * against each other.
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
            var lowestCost = Double.MAX_VALUE
            for (index in 0 until segmentCount) {
                if (distances[index] > distances[closest] + HINT_SLACK_METERS) {
                    continue
                }
                val moved = alongs[index] - hintMeters
                val cost = distances[index] + if (moved >= 0.0) {
                    FORWARD_COST_PER_METER * moved
                } else {
                    BACKWARD_COST_PER_METER * -moved
                }
                if (cost < lowestCost) {
                    lowestCost = cost
                    chosen = index
                }
            }
        }
        return RideProjection(alongs[chosen], distances[chosen], chosen)
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

        /**
         * What a metre of travel along the route weighs against a metre of
         * distance from it. Small, so that a fix lying on one leg is not
         * placed on another 40 m off; not nothing, so that the same street
         * used twice a kilometre apart is not decided by a few metres of noise.
         */
        const val FORWARD_COST_PER_METER = 0.05
        const val BACKWARD_COST_PER_METER = 0.2
        const val STOP_REACHED_TOLERANCE_METERS = 25.0
    }
}
