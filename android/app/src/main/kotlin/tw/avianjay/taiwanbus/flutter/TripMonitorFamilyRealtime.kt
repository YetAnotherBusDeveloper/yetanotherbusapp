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
    // Read and filled from the service's fetch threads, more than one at a time.
    private val cachedTopologies = java.util.concurrent.ConcurrentHashMap<String, JSONObject>()

    /**
     * The stops of [session]'s path that [routeId], another route of the
     * family, also calls at in that direction — matched as the live feed's
     * stops are, by id or by name and place. Null when its stops could not be
     * fetched.
     */
    fun stopsServedBy(session: TrackingSession, routeId: String): Set<Int>? {
        val topology = topologyOf(routeId) ?: return null
        val variantStops = stopsForDirection(topology, session.pathId)
        return session.stops
            .filter { selected -> variantStops.any { sameSide(selected, it) } }
            .map { it.stopId }
            .toSet()
    }

    private fun topologyOf(routeId: String): JSONObject? = cachedTopologies[routeId]
        ?: fetchJson("routes/${encode(routeId)}/stops")?.also { cachedTopologies[routeId] = it }

    fun fetch(session: TrackingSession): Map<Int, LiveStopState> {
        val ids = session.realtimeRouteIds
        if (ids.isEmpty()) return emptyMap()
        if (ids.size == 1) {
            val snapshot = fetchJson("routes/${encode(ids.single())}/realtime") ?: return emptyMap()
            return liveStops(snapshot, session.pathId, source = ids.single(), fallbackDirection = true)
        }

        val snapshots = mutableMapOf<String, JSONObject>()
        for (batch in ids.chunked(25)) {
            val path = batch.joinToString(",") { encode(it) }
            val routes = fetchJson("batchroutes/$path/realtime")?.optJSONObject("routes") ?: continue
            for (id in batch) routes.optJSONObject(id)?.let { snapshots[id] = it }
        }

        val merged = snapshots[session.routeId]?.let {
            liveStops(it, session.pathId, source = session.routeId.orEmpty(), fallbackDirection = true)
        }.orEmpty().toMutableMap()
        for (id in ids.filter { it != session.routeId }) {
            val snapshot = snapshots[id] ?: continue
            val variantLive = liveStops(snapshot, session.pathId, source = id)
            if (variantLive.isEmpty()) continue
            val topology = topologyOf(id) ?: continue
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
    source: String,
    fallbackDirection: Boolean = false,
): Map<Int, LiveStopState> = buildMap {
    for (stop in stopsForDirection(snapshot, direction, fallbackDirection)) {
        val id = stopId(stop.opt("stopid"))
        if (id > 0) put(id, parseTripMonitorLiveStop(stop, source))
    }
}

/**
 * One stop of the live feed.
 *
 * `buses` is not "the buses at this stop". The backend lists each vehicle under
 * the stop it will reach next, so a bus a quarter of an hour away appears in
 * the `buses` of the stop it is heading for: in recorded 台中 and 高雄 feeds a
 * fifth to a third of those vehicles were more than ten minutes out. What does
 * place a vehicle at a stop is its own ETA entry there: `is_arriving`, which
 * the backend sets from the vehicle's own stop status, or an estimate that has
 * run out.
 *
 * The same shape arrives from the route screen while the app is open, with
 * things added: `observedEta`, the estimate as the backend gave it where `eta`
 * has since been counted down for display, and `observedAtMs`, when the
 * backend made the observation. From the backend itself that moment is
 * `eta_reference_at`, in seconds. Where the screen has merged the routes of a
 * family into the stop, `observations` lists what each of them observed —
 * its estimate, when, and whether it had a bus arriving — and each entry of
 * `etas` names the `routes` that listed it.
 *
 * [source] is the route this stop's own estimate is from.
 */
internal fun parseTripMonitorLiveStop(stop: JSONObject, source: String = ""): LiveStopState {
    val etas = stop.optJSONArray("etas").objects().mapNotNull { eta ->
        val seconds = integer(eta.opt("eta"))
        LiveEtaEntry(
            seconds = seconds,
            message = text(eta, "message"),
            vehicleId = vehicle(eta, "plate", "vehicle_id", "id"),
            isArriving = eta.optBoolean("is_arriving", false),
            observedSeconds = if (eta.has("observedEta")) integer(eta.opt("observedEta")) else seconds,
            sources = eta.optJSONArray("routes")
                ?.let { routes -> (0 until routes.length()).mapNotNull { routes.optString(it).takeIf(String::isNotEmpty) } }
                ?.takeIf { it.isNotEmpty() }?.toSet()
                ?: setOf(source),
            // The flag alone is something said of a bus: one at the stop that
            // the feed neither names nor has an estimate for.
        ).takeIf { it.seconds != null || it.message != null || it.vehicleId != null || it.isArriving }
    }
    val buses = stop.optJSONArray("buses").objects()
        .mapNotNull { vehicle(it, "id", "vehicle_id", "plate") }
    val seconds = integer(stop.opt("eta"))
    val merged = stop.optJSONArray("observations").objects().map { observation ->
        StopObservation(
            source = text(observation, "source") ?: source,
            seconds = integer(observation.opt("eta")),
            atMs = long(observation.opt("atMs")),
            arriving = observation.optBoolean("arriving", false) ||
                saysABusIsArriving(text(observation, "message")),
        )
    }
    val message = text(stop, "message")
    return LiveStopState(
        seconds = seconds,
        message = message,
        vehicleIds = (buses + etas.mapNotNull { it.vehicleId }).distinct(),
        etaEntries = etas,
        observations = merged.ifEmpty {
            listOf(
                StopObservation(
                    source = source,
                    seconds = if (stop.has("observedEta")) integer(stop.opt("observedEta")) else seconds,
                    atMs = long(stop.opt("observedAtMs"))
                        ?: long(stop.opt("eta_reference_at"))?.let { it * 1_000L },
                    arriving = etas.any { it.isArriving } || saysABusIsArriving(message),
                ),
            )
        },
    )
}

private fun mergeStops(stops: List<LiveStopState>): LiveStopState {
    val earliest = stops.filter { it.seconds != null && it.seconds >= 0 }.minByOrNull { it.seconds!! }
    val entries = stops.flatMap { stop ->
        // A vehicle listed without an estimate of its own is shown with the
        // stop's, and marked as such: that estimate is some bus's, not
        // necessarily this one's, and says nothing of where this one is.
        stop.etaEntries + stop.vehicleIds
            .filter { id -> stop.etaEntries.none { it.vehicleId == id } }
            .map {
                LiveEtaEntry(
                    stop.seconds, stop.message, it, listedOnly = true,
                    sources = stop.observations.map { observation -> observation.source }.toSet(),
                )
            }
        // One entry for a bus two routes say the same of, listed by both.
    }.groupBy { it.copy(sources = emptySet()) }
        .map { (entry, listings) -> entry.copy(sources = listings.flatMap { it.sources }.toSet()) }
        .sortedBy { it.seconds?.takeIf { seconds -> seconds >= 0 } ?: Int.MAX_VALUE }
    return LiveStopState(
        seconds = earliest?.seconds,
        message = if (earliest == null) stops.firstNotNullOfOrNull { it.message } else null,
        vehicleIds = (entries.mapNotNull { it.vehicleId } + stops.flatMap { it.vehicleIds }).distinct(),
        etaEntries = entries,
        // The badge shows the soonest bus still to come. What was observed
        // stays as each route observed it, estimate and moment together: the
        // soonest estimate with the latest moment would be an observation
        // nobody made, and one route's estimate at -1 — a bus at the stop, or
        // a stop nobody is counting down to — says nothing of another's. Nor
        // does one route's bus arriving make it another's, or as recent.
        observations = stops.flatMap { it.observations }.distinctBy { it.source },
    )
}

private fun JSONArray?.objects(): List<JSONObject> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }

private fun integer(raw: Any?): Int? = if (raw is Number) raw.toInt() else raw?.toString()?.trim()?.toIntOrNull()

private fun long(raw: Any?): Long? = if (raw is Number) raw.toLong() else raw?.toString()?.trim()?.toLongOrNull()

internal fun stopId(raw: Any?): Int = foldStopId(raw)

private fun text(json: JSONObject, key: String): String? = json.opt(key)
    ?.takeUnless { it == JSONObject.NULL }?.toString()?.trim()
    ?.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }

private fun vehicle(json: JSONObject, vararg keys: String): String? = keys.firstNotNullOfOrNull {
    text(json, it)?.replace(" ", "")?.uppercase()?.takeIf { id -> id.isNotEmpty() }
}
