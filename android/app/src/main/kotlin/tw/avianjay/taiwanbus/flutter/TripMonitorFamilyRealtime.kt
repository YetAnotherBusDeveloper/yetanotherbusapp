package tw.avianjay.taiwanbus.flutter

import java.net.URLEncoder
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import org.json.JSONArray
import org.json.JSONObject

/** Loads the selected route and its variants for the background trip monitor. */
internal class TripMonitorFamilyRealtime(
    private val fetchJson: (String) -> JSONObject?,
) {
    private val cachedTopologies = mutableMapOf<String, JSONObject>()

    // Called only on the service's single IO executor.
    fun fetch(session: TrackingSession): Map<Int, LiveStopState> {
        val ids = session.realtimeRouteIds
        if (ids.isEmpty()) return emptyMap()
        if (ids.size == 1) {
            val snapshot = fetchJson("routes/${encode(ids.single())}/realtime") ?: return emptyMap()
            return liveStops(snapshot, session.pathId, fallbackDirection = true)
        }

        val snapshots = mutableMapOf<String, JSONObject>()
        for (batch in ids.chunked(25)) {
            val path = batch.joinToString(",") { encode(it) }
            val routes = fetchJson("batchroutes/$path/realtime")?.optJSONObject("routes") ?: continue
            for (id in batch) routes.optJSONObject(id)?.let { snapshots[id] = it }
        }

        val merged = snapshots[session.routeId]?.let {
            liveStops(it, session.pathId, fallbackDirection = true)
        }.orEmpty().toMutableMap()
        for (id in ids.filter { it != session.routeId }) {
            val snapshot = snapshots[id] ?: continue
            val variantLive = liveStops(snapshot, session.pathId)
            if (variantLive.isEmpty()) continue
            val topology = cachedTopologies[id]
                ?: fetchJson("routes/${encode(id)}/stops")?.also { cachedTopologies[id] = it }
                ?: continue
            val variantStops = stopsForDirection(topology, session.pathId)
            for (selected in session.stops) {
                val shared = variantStops.filter { sameSide(selected, it) }
                    .mapNotNull { variantLive[stopId(it.opt("stopid"))] }
                if (shared.isNotEmpty()) {
                    merged[selected.stopId] = mergeStops(listOfNotNull(merged[selected.stopId]) + shared)
                }
            }
        }
        return merged
    }

    private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())

    private fun sameSide(selected: TrackingStop, variant: JSONObject): Boolean {
        val rawId = text(variant, "stopid")
        if (rawId != null && (
                selected.rawStopId?.trim()?.takeIf { it.isNotEmpty() } == rawId ||
                    (selected.rawStopId.isNullOrBlank() && selected.stopId == stopId(rawId))
                )) {
            return true
        }
        val name = text(variant, "name") ?: return false
        val whitespace = Regex("\\s+")
        if (selected.stopName.trim().replace(whitespace, "") != name.replace(whitespace, "")) {
            return false
        }
        val lat = variant.optDouble("lat", 0.0)
        val lon = variant.optDouble("lon", 0.0)
        if ((selected.lat == 0.0 && selected.lon == 0.0) || (lat == 0.0 && lon == 0.0)) return false
        val deltaLat = Math.toRadians(lat - selected.lat)
        val deltaLon = Math.toRadians(lon - selected.lon)
        val a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(Math.toRadians(selected.lat)) * cos(Math.toRadians(lat)) *
            sin(deltaLon / 2) * sin(deltaLon / 2)
        return 6378137.0 * 2 * atan2(sqrt(a), sqrt(1 - a)) <= 60
    }
}

private fun stopsForDirection(
    snapshot: JSONObject,
    direction: Int,
    fallbackDirection: Boolean = false,
): List<JSONObject> {
    val paths = snapshot.optJSONArray("paths").objects()
    val matched = paths.filter { integer(it.opt("pathid")) == direction }
    return (if (matched.isEmpty() && fallbackDirection) paths else matched)
        .flatMap { it.optJSONArray("stops").objects() }
}

private fun liveStops(
    snapshot: JSONObject,
    direction: Int,
    fallbackDirection: Boolean = false,
): Map<Int, LiveStopState> = buildMap {
    for (stop in stopsForDirection(snapshot, direction, fallbackDirection)) {
        val id = stopId(stop.opt("stopid"))
        if (id > 0) put(id, parseTripMonitorLiveStop(stop))
    }
}

internal fun parseTripMonitorLiveStop(stop: JSONObject): LiveStopState {
    val etas = stop.optJSONArray("etas").objects().mapNotNull { eta ->
        LiveEtaEntry(
            seconds = integer(eta.opt("eta")),
            message = text(eta, "message"),
            vehicleId = vehicle(eta, "plate", "vehicle_id", "id"),
        ).takeIf { it.seconds != null || it.message != null || it.vehicleId != null }
    }
    val buses = stop.optJSONArray("buses").objects()
        .mapNotNull { vehicle(it, "id", "vehicle_id", "plate") }
    return LiveStopState(
        seconds = integer(stop.opt("eta")),
        message = text(stop, "message"),
        vehicleIds = (buses + etas.mapNotNull { it.vehicleId }).distinct(),
        etaEntries = etas,
    )
}

private fun mergeStops(stops: List<LiveStopState>): LiveStopState {
    val earliest = stops.filter { it.seconds != null && it.seconds >= 0 }.minByOrNull { it.seconds!! }
    val entries = stops.flatMap { stop ->
        stop.etaEntries + stop.vehicleIds
            .filter { id -> stop.etaEntries.none { it.vehicleId == id } }
            .map { LiveEtaEntry(stop.seconds, stop.message, it) }
    }.distinct().sortedBy { it.seconds?.takeIf { seconds -> seconds >= 0 } ?: Int.MAX_VALUE }
    return LiveStopState(
        seconds = earliest?.seconds,
        message = if (earliest == null) stops.firstNotNullOfOrNull { it.message } else null,
        vehicleIds = (entries.mapNotNull { it.vehicleId } + stops.flatMap { it.vehicleIds }).distinct(),
        etaEntries = entries,
    )
}

private fun JSONArray?.objects(): List<JSONObject> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }

private fun integer(raw: Any?): Int? = if (raw is Number) raw.toInt() else raw?.toString()?.trim()?.toIntOrNull()

internal fun stopId(raw: Any?): Int {
    if (raw is Number) return raw.toInt()
    val value = raw?.takeUnless { it == JSONObject.NULL }?.toString()?.trim().orEmpty()
    if (value.isEmpty()) return 0
    value.toIntOrNull()?.let { return it }
    var hash = 17
    for (char in value) hash = (hash * 31 + char.code) and 0x7fffffff
    return hash
}

private fun text(json: JSONObject, key: String): String? = json.opt(key)
    ?.takeUnless { it == JSONObject.NULL }?.toString()?.trim()
    ?.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }

private fun vehicle(json: JSONObject, vararg keys: String): String? = keys.firstNotNullOfOrNull {
    text(json, it)?.replace(" ", "")?.uppercase()?.takeIf { id -> id.isNotEmpty() }
}
