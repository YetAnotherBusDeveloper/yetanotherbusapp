package tw.avianjay.taiwanbus.flutter

import java.net.URLEncoder
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import org.json.JSONArray
import org.json.JSONObject

/** Fetches the same route family shown in Flutter, using the selected route's stop identities. */
internal class TripMonitorRealtimeClient(
    private val fetchJson: (String) -> JSONObject?,
) {
    // Only used by the service's single IO executor. Static stops last for the service's lifetime.
    private val topologies = mutableMapOf<String, JSONObject>()

    fun fetch(session: TrackingSession): Map<Int, LiveStopState> {
        val routeIds = session.realtimeRouteIds
        if (routeIds.isEmpty()) return emptyMap()
        if (routeIds.size == 1) {
            val root = fetchJson("routes/${encode(routeIds.single())}/realtime")
                ?: return emptyMap()
            return parseLiveStops(root, session.pathId, allowPathFallback = true)
        }

        val snapshots = mutableMapOf<String, JSONObject>()
        for (chunk in routeIds.chunked(25)) {
            val ids = chunk.joinToString(",") { encode(it) }
            val routes = fetchJson("batchroutes/$ids/realtime")?.optJSONObject("routes") ?: continue
            for (routeId in chunk) {
                routes.optJSONObject(routeId)?.let { snapshots[routeId] = it }
            }
        }

        val result = snapshots[session.routeId]?.let {
            parseLiveStops(it, session.pathId, allowPathFallback = true)
        }.orEmpty().toMutableMap()
        for (routeId in routeIds.filter { it != session.routeId }) {
            val snapshot = snapshots[routeId] ?: continue
            // Never fall back to the opposite direction for a variant.
            val liveStops = parseLiveStops(snapshot, session.pathId)
            if (liveStops.isEmpty()) continue
            val topology = topologies[routeId]
                ?: fetchJson("routes/${encode(routeId)}/stops")?.also { topologies[routeId] = it }
                ?: continue
            val variantStops = pathStops(topology, session.pathId)
            for (stop in session.stops) {
                val shared = variantStops.filter { sharesPhysicalSide(stop, it) }
                    .mapNotNull { liveStops[tripMonitorStopId(it.opt("stopid"))] }
                if (shared.isEmpty()) continue
                result[stop.stopId] = mergeLiveStops(listOfNotNull(result[stop.stopId]) + shared)
            }
        }
        return result
    }

    private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())

    private fun sharesPhysicalSide(selected: TrackingStop, variant: JSONObject): Boolean {
        val rawId = jsonText(variant, "stopid")
        if (rawId != null && (
                selected.rawStopId?.takeIf { it.isNotBlank() } == rawId ||
                    (selected.rawStopId.isNullOrBlank() && selected.stopId == tripMonitorStopId(rawId))
                )) return true
        val name = jsonText(variant, "name") ?: return false
        val whitespace = Regex("\\s+")
        if (selected.stopName.trim().replace(whitespace, "") != name.replace(whitespace, "")) return false
        val lat = variant.optDouble("lat", 0.0)
        val lon = variant.optDouble("lon", 0.0)
        if ((selected.lat == 0.0 && selected.lon == 0.0) || (lat == 0.0 && lon == 0.0)) return false
        val latitudeDelta = Math.toRadians(lat - selected.lat)
        val longitudeDelta = Math.toRadians(lon - selected.lon)
        val a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
            cos(Math.toRadians(selected.lat)) * cos(Math.toRadians(lat)) *
            sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return 6378137.0 * 2 * atan2(sqrt(a), sqrt(1 - a)) <= 60
    }
}

private fun pathStops(root: JSONObject, pathId: Int, allowPathFallback: Boolean = false): List<JSONObject> {
    val paths = root.optJSONArray("paths").objects()
    val matching = paths.filter { jsonInt(it.opt("pathid")) == pathId }
    val selected = if (matching.isEmpty() && allowPathFallback) paths else matching
    return selected.flatMap { it.optJSONArray("stops").objects() }
}

private fun parseLiveStops(
    root: JSONObject,
    pathId: Int,
    allowPathFallback: Boolean = false,
): Map<Int, LiveStopState> = buildMap {
    for (stop in pathStops(root, pathId, allowPathFallback)) {
        val stopId = tripMonitorStopId(stop.opt("stopid"))
        if (stopId > 0) put(stopId, parseTripMonitorLiveStop(stop))
    }
}

internal fun parseTripMonitorLiveStop(stop: JSONObject): LiveStopState {
    val etas = stop.optJSONArray("etas").objects().mapNotNull { eta ->
        val entry = LiveEtaEntry(
            seconds = jsonInt(eta.opt("eta")),
            message = jsonText(eta, "message"),
            vehicleId = vehicleId(eta, "plate", "vehicle_id", "id"),
        )
        entry.takeIf { it.seconds != null || it.message != null || it.vehicleId != null }
    }
    val vehicles = stop.optJSONArray("buses").objects()
        .mapNotNull { vehicleId(it, "id", "vehicle_id", "plate") }
    return LiveStopState(
        seconds = jsonInt(stop.opt("eta")),
        message = jsonText(stop, "message"),
        vehicleIds = (vehicles + etas.mapNotNull { it.vehicleId }).distinct(),
        etaEntries = etas,
    )
}

private fun mergeLiveStops(stops: List<LiveStopState>): LiveStopState {
    val primary = stops.filter { it.seconds != null && it.seconds >= 0 }.minByOrNull { it.seconds!! }
    val etas = stops.flatMap { stop ->
        // Some feeds supply vehicles without per-vehicle ETAs. Preserve their own route's ETA.
        stop.etaEntries + stop.vehicleIds.filter { id -> stop.etaEntries.none { it.vehicleId == id } }
            .map { LiveEtaEntry(stop.seconds, stop.message, it) }
    }.distinct().sortedBy { it.seconds?.takeIf { seconds -> seconds >= 0 } ?: Int.MAX_VALUE }
    return LiveStopState(
        seconds = primary?.seconds,
        message = if (primary != null) null else stops.firstNotNullOfOrNull { it.message },
        vehicleIds = (etas.mapNotNull { it.vehicleId } + stops.flatMap { it.vehicleIds }).distinct(),
        etaEntries = etas,
    )
}

internal fun tripMonitorStopId(raw: Any?): Int {
    if (raw is Number) return raw.toInt()
    val text = raw?.takeUnless { it == JSONObject.NULL }?.toString()?.trim().orEmpty()
    if (text.isEmpty()) return 0
    text.toIntOrNull()?.let { return it }
    var hash = 17
    for (char in text) hash = (hash * 31 + char.code) and 0x7fffffff
    return hash
}

private fun JSONArray?.objects(): List<JSONObject> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }

private fun jsonInt(raw: Any?): Int? = if (raw is Number) raw.toInt() else raw?.toString()?.trim()?.toIntOrNull()

private fun jsonText(value: JSONObject, key: String): String? = value.opt(key)
    ?.takeUnless { it == JSONObject.NULL }?.toString()?.trim()?.takeIf { it.isNotEmpty() && it != "null" }

private fun vehicleId(value: JSONObject, vararg keys: String): String? = keys.firstNotNullOfOrNull {
    jsonText(value, it)?.replace(" ", "")?.uppercase()?.takeIf { id -> id.isNotEmpty() }
}
