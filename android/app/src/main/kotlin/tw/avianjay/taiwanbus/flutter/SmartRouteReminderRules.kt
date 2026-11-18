package tw.avianjay.taiwanbus.flutter

import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.max
import kotlin.math.roundToInt
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.decodeFromJsonElement

/**
 * One stretch of one weekday in which a route is worth a reminder.
 *
 * Written by the Flutter side (`SmartRoutePlanner`), which is where the habit
 * is learned. Nothing here scores a habit: this side only follows the plan,
 * so the two can never disagree about what the rider's routine is.
 */
@Serializable
internal data class SmartPlanSlot(
    val provider: String,
    val routeKey: Int,
    /** What the stop database and the realtime API know the route by. */
    val routeId: String,
    val pathId: Int,
    val routeName: String = "",
    /** 1 = Monday .. 7 = Sunday, of the service day. */
    val weekday: Int,
    /** Minutes since the service day began, both ends inclusive. */
    val startMinute: Int,
    val endMinute: Int,
    /** When within the window the route is most often opened. */
    val peakMinute: Int,
    val confidence: Double = 0.0,
    val supportDays: Int = 0,
    /** The habit has gone unconfirmed for too long once this has passed. */
    val validUntilMs: Long,
    /** When the rider last opened or chose this route in the app. */
    val lastActivityAtMs: Long = 0L,
    /** The stop to watch, as Flutter holds stop ids. Null when none is known. */
    val stopId: Long? = null,
)

@Serializable
internal data class SmartRoutePlan(
    val version: Int,
    val generatedAtMs: Long = 0L,
    /** The hour at which a service day begins; slot minutes count from it. */
    val dayStartHour: Int = 4,
    val slots: List<SmartPlanSlot> = emptyList(),
)

/** Where a moment falls on the plan's service-day grid. */
internal data class SmartServiceClock(
    /** The same all service day and different the next; nothing more. */
    val day: Long,
    val weekday: Int,
    val minute: Int,
)

internal data class SmartRouteStop(
    val pathId: Int,
    /** As the stop database and the live feed both spell it. */
    val rawStopId: String,
    val stopName: String,
    val sequence: Int,
    val lon: Double,
    val lat: Double,
)

/** The stop a reminder will be about. */
internal data class SmartStopChoice(
    val stop: SmartRouteStop,
    /** Straight-line distance from the device, when its location is known. */
    val distanceMeters: Double?,
)

internal data class SmartLiveStop(
    val sec: Int?,
    val msg: String?,
    /** Every timed arrival the feed lists for the stop, in seconds. */
    val arrivals: List<Int> = emptyList(),
)

/** A bus worth telling the rider about. */
internal data class SmartEtaDecision(
    val etaSeconds: Int,
    /** The one after it, so a reminder that is read late is still of use. */
    val followingEtaSeconds: Int?,
)

/** What has already been sent, so the next reminder can be held back. */
internal data class SmartReminderHistory(
    val lastAnyMs: Long = 0L,
    val countDay: Long = 0L,
    val countThatDay: Int = 0,
)

internal data class SmartReminderText(
    val title: String,
    val text: String,
    val bigText: String,
)

/**
 * A reminder that was actually shown.
 *
 * Kept for the Flutter side, which learns the rider's habits from when they
 * open a route. A reminder changes that: one that did its job takes away the
 * reason to open the route at all, and one that is tapped has it opened at
 * the reminder's time instead of the rider's own. Read without this, the
 * first would look like a day the rider stayed home and the second like a
 * routine that had moved earlier.
 */
@Serializable
internal data class SmartReminderLogEntry(
    val provider: String,
    val routeKey: Int,
    val pathId: Int,
    val atMs: Long,
    /** The [SmartPlanSlot.peakMinute] of the slot the reminder was for. */
    val peakMinute: Int? = null,
)

internal object SmartRouteReminderRules {
    /** Plans of any other version are ignored rather than half-understood. */
    const val SUPPORTED_PLAN_VERSION = 1

    /**
     * How long before the rider's usual time a reminder may go out. One
     * period of the background check, so that a check lands in it; any
     * earlier and the bus reported is one they would not have taken.
     */
    const val LEAD_MINUTES = 15

    /**
     * Opening the route this long before its window, or any time since, means
     * the rider has already looked: a reminder would only repeat the screen
     * they just closed.
     */
    const val SEEN_BEFORE_WINDOW_MS = 30 * 60 * 1000L

    /** One reminder per route per window; windows are hours apart. */
    const val ROUTE_COOLDOWN_MS = 3 * 60 * 60 * 1000L

    /** Two routes due at once do not get to arrive as a burst. */
    const val MIN_GAP_MS = 20 * 60 * 1000L
    const val MAX_PER_DAY = 6

    /** Farther than this from the usual stop, the rider is somewhere else today. */
    const val USUAL_STOP_REACH_METERS = 1000.0

    /** Without a usual stop, only one this close is taken to be theirs. */
    const val NEAREST_STOP_REACH_METERS = 800.0

    /**
     * Straight-line metres covered per second on foot. Slower than anyone
     * walks, because the straight line is shorter than the pavement.
     */
    const val WALK_METERS_PER_SECOND = 1.0
    const val WALK_BUFFER_SECONDS = 60

    /** A bus closer than this cannot be caught by someone not yet at the stop. */
    const val MIN_ETA_SECONDS = 3 * 60

    /** A bus farther off than this is not news yet; the next check will see it. */
    const val MAX_ETA_SECONDS = 25 * 60

    /** A stop whose estimate is older than this is not a basis for a reminder. */
    const val MAX_FEED_AGE_MS = 5 * 60 * 1000L

    /** As far back as the habit model looks; older entries can change nothing. */
    const val REMINDER_LOG_RETENTION_MS = 56L * 24 * 60 * 60 * 1000
    const val REMINDER_LOG_MAX_ENTRIES = 400

    /**
     * How long before a slot lapses its reminders start saying that it will.
     * A rider the reminders work for has no cause to open the app, and would
     * otherwise learn that the habit needs confirming only when they stop.
     */
    const val LAPSE_NOTICE_MS = 3L * 24 * 60 * 60 * 1000

    private const val POST_ARRIVAL_LINGER_SECONDS = 3 * 60

    private val json = Json { ignoreUnknownKeys = true }

    fun parsePlan(raw: String?): SmartRoutePlan? {
        if (raw.isNullOrBlank()) {
            return null
        }
        val plan = try {
            json.decodeFromString<SmartRoutePlan>(raw)
        } catch (_: Exception) {
            return null
        }
        return plan.takeIf {
            it.version == SUPPORTED_PLAN_VERSION && it.dayStartHour in 0..23
        }
    }

    fun serviceClock(
        nowMs: Long,
        dayStartHour: Int,
        zone: TimeZone = TimeZone.getDefault(),
    ): SmartServiceClock {
        val calendar = Calendar.getInstance(zone).apply {
            timeInMillis = nowMs - dayStartHour * 60 * 60 * 1000L
        }
        return SmartServiceClock(
            day = calendar.get(Calendar.YEAR) * 1000L + calendar.get(Calendar.DAY_OF_YEAR),
            // Calendar counts from Sunday = 1; the plan from Monday = 1.
            weekday = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1,
            minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE),
        )
    }

    /**
     * Slots a reminder may go out for right now, the most certain first, one
     * per route and direction.
     */
    fun dueSlots(
        plan: SmartRoutePlan,
        provider: String,
        nowMs: Long,
        zone: TimeZone = TimeZone.getDefault(),
    ): List<SmartPlanSlot> {
        val clock = serviceClock(nowMs, plan.dayStartHour, zone)
        return plan.slots
            .filter { slot ->
                slot.provider == provider &&
                    slot.weekday == clock.weekday &&
                    clock.minute >= max(slot.startMinute, slot.peakMinute - LEAD_MINUTES) &&
                    clock.minute <= slot.endMinute &&
                    nowMs < slot.validUntilMs
            }
            .sortedByDescending { it.confidence }
            .distinctBy { it.routeKey to it.pathId }
    }

    /** Whether any slot at all could still fire, now or on a later day. */
    fun hasLiveSlots(plan: SmartRoutePlan, nowMs: Long): Boolean =
        plan.slots.any { nowMs < it.validUntilMs }

    /** Whether [slot] will lapse soon enough that its reminder should say so. */
    fun isAboutToLapse(slot: SmartPlanSlot, nowMs: Long): Boolean =
        slot.validUntilMs - nowMs <= LAPSE_NOTICE_MS

    /** Whether the rider has had the route open since shortly before [slot] began. */
    fun wasSeenForWindow(slot: SmartPlanSlot, nowMs: Long, nowMinute: Int): Boolean {
        val windowStartMs = nowMs - (nowMinute - slot.startMinute) * 60_000L
        return slot.lastActivityAtMs >= windowStartMs - SEEN_BEFORE_WINDOW_MS
    }

    fun mayRemind(history: SmartReminderHistory, nowMs: Long, today: Long): Boolean {
        if (nowMs - history.lastAnyMs < MIN_GAP_MS) {
            return false
        }
        return history.countDay != today || history.countThatDay < MAX_PER_DAY
    }

    fun mayRemindRoute(lastForRouteMs: Long, nowMs: Long): Boolean =
        nowMs - lastForRouteMs >= ROUTE_COOLDOWN_MS

    fun afterReminder(history: SmartReminderHistory, nowMs: Long, today: Long) =
        SmartReminderHistory(
            lastAnyMs = nowMs,
            countDay = today,
            countThatDay = if (history.countDay == today) history.countThatDay + 1 else 1,
        )

    /** Entries that cannot be read are passed over; the rest are still good. */
    fun parseReminderLog(log: String?): List<SmartReminderLogEntry> {
        if (log.isNullOrBlank()) {
            return emptyList()
        }
        val entries = try {
            json.parseToJsonElement(log) as? JsonArray
        } catch (_: Exception) {
            null
        } ?: return emptyList()
        return entries.mapNotNull { entry ->
            try {
                json.decodeFromJsonElement<SmartReminderLogEntry>(entry)
            } catch (_: Exception) {
                null
            }
        }
    }

    /**
     * [log] with a reminder shown at [nowMs] for [slot] added, and whatever
     * is too old to matter dropped.
     */
    fun appendToReminderLog(log: String?, slot: SmartPlanSlot, nowMs: Long): String {
        val kept = parseReminderLog(log).filter { nowMs - it.atMs < REMINDER_LOG_RETENTION_MS } +
            SmartReminderLogEntry(
                provider = slot.provider,
                routeKey = slot.routeKey,
                pathId = slot.pathId,
                atMs = nowMs,
                peakMinute = slot.peakMinute,
            )
        return json.encodeToString(kept.takeLast(REMINDER_LOG_MAX_ENTRIES))
    }

    /** The plan's usual stop among [stops], matched by the id Flutter holds. */
    fun findUsualStop(slot: SmartPlanSlot, stops: List<SmartRouteStop>): SmartRouteStop? {
        val usualStopId = slot.stopId?.takeIf { it > 0L } ?: return null
        return stops.firstOrNull { stop ->
            stop.pathId == slot.pathId && launchStopId(stop.rawStopId) == usualStopId
        }
    }

    /**
     * Picks the stop to watch.
     *
     * The stop the rider usually uses comes first, and needs no location at
     * all. Location, when there is one, can only overrule it: far from the
     * usual stop, the nearest one stands in if the rider is close to the
     * route, and otherwise there is nothing to remind them of.
     *
     * A distance is null when it could not be measured — no location, or a
     * stop without coordinates.
     */
    fun chooseStop(
        usualStop: SmartRouteStop?,
        usualDistanceMeters: Double?,
        nearestStop: SmartRouteStop?,
        nearestDistanceMeters: Double?,
    ): SmartStopChoice? {
        if (usualStop != null) {
            if (usualDistanceMeters == null) {
                return SmartStopChoice(usualStop, distanceMeters = null)
            }
            if (usualDistanceMeters <= USUAL_STOP_REACH_METERS) {
                return SmartStopChoice(usualStop, usualDistanceMeters)
            }
        }
        if (nearestStop != null &&
            nearestDistanceMeters != null &&
            nearestDistanceMeters <= NEAREST_STOP_REACH_METERS
        ) {
            return SmartStopChoice(nearestStop, nearestDistanceMeters)
        }
        return null
    }

    /**
     * Reads one stop out of a `/routes/{id}/realtime` response.
     *
     * Only [pathId] is searched. The same stop id can sit on both directions
     * of a route, and the other direction's bus is the one going the wrong
     * way.
     */
    fun parseLiveStop(
        jsonText: String,
        pathId: Int,
        rawStopId: String,
        nowMs: Long,
    ): SmartLiveStop? {
        val root = try {
            json.parseToJsonElement(jsonText) as? JsonObject
        } catch (_: Exception) {
            null
        } ?: return null
        val wanted = rawStopId.trim()
        for (pathElement in root["paths"] as? JsonArray ?: return null) {
            val path = pathElement as? JsonObject ?: continue
            if (path["pathid"].asInt() != pathId) {
                continue
            }
            for (stopElement in path["stops"] as? JsonArray ?: continue) {
                val stop = stopElement as? JsonObject ?: continue
                if (stop["stopid"].asText() != wanted) {
                    continue
                }
                if (isOutdated(stop["updated_at"].asLong(), nowMs)) {
                    return null
                }
                return SmartLiveStop(
                    sec = stop["eta"].asInt(),
                    msg = stop["message"].asText(),
                    arrivals = (stop["etas"] as? JsonArray).orEmpty().mapNotNull { eta ->
                        // An arrival that comes with a message is a status,
                        // not a time: "未發車" may still carry a timetable guess.
                        (eta as? JsonObject)
                            ?.takeIf { it["message"].asText() == null }
                            ?.get("eta")
                            .asInt()
                    },
                )
            }
        }
        return null
    }

    fun walkingSeconds(distanceMeters: Double): Int =
        (distanceMeters / WALK_METERS_PER_SECOND).roundToInt() + WALK_BUFFER_SECONDS

    /**
     * The first bus the rider could still catch, if it is close enough to be
     * worth saying so.
     *
     * A stop that carries a message instead of a time is in some state — not
     * yet departed, not served today, last bus gone — and none of those is a
     * reason to tell anyone to leave the house. Only a timed arrival counts.
     */
    fun decide(liveStop: SmartLiveStop, distanceMeters: Double?): SmartEtaDecision? {
        val message = liveStop.msg?.trim().orEmpty()
        if (isLastBusMessage(message)) {
            return null
        }
        val arrivals = buildList<Int> {
            if (message.isEmpty()) {
                liveStop.sec?.let { add(it) }
            }
            addAll(liveStop.arrivals)
        }.filter { it >= 0 }.distinct().sorted()
        val soonestCatchable = max(
            MIN_ETA_SECONDS,
            distanceMeters?.let(::walkingSeconds) ?: 0,
        )
        val index = arrivals.indexOfFirst { it >= soonestCatchable }
        if (index < 0 || arrivals[index] > MAX_ETA_SECONDS) {
            return null
        }
        return SmartEtaDecision(
            etaSeconds = arrivals[index],
            followingEtaSeconds = arrivals.getOrNull(index + 1),
        )
    }

    fun buildText(
        routeName: String,
        pathName: String?,
        stopName: String,
        decision: SmartEtaDecision,
        distanceMeters: Double?,
        slot: SmartPlanSlot,
        dayStartHour: Int,
        nowMs: Long,
        zone: TimeZone = TimeZone.getDefault(),
    ): SmartReminderText {
        val route = routeName.ifBlank { "路線" }
        // The clock time as well as the countdown: a reminder read ten
        // minutes late still says when the bus was due.
        val arrivalClock = formatClock(nowMs + decision.etaSeconds * 1000L, zone)
        val following = decision.followingEtaSeconds
            ?.let { "，下一班約 ${etaMinutes(it)} 分後" }
            .orEmpty()
        val direction = pathName?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { "方向：$it。" }
            .orEmpty()
        val distance = distanceMeters
            ?.let { "距離你約 ${formatDistance(it)}。" }
            .orEmpty()
        val usualClock = formatMinuteOfDay(
            ((slot.peakMinute / 5.0).roundToInt() * 5 + dayStartHour * 60) % (24 * 60),
        )
        // Said while opening the route can still prevent it, rather than
        // leaving the reminders to stop one morning without a word.
        val lapseNotice = if (isAboutToLapse(slot, nowMs)) {
            "\n已有一段時間沒有開啟這條路線，提醒即將暫停；點這則通知查看路線即可繼續收到。"
        } else {
            ""
        }
        return SmartReminderText(
            title = "$route 約 ${etaMinutes(decision.etaSeconds)} 分後到站",
            text = "$stopName · 預計 $arrivalClock 到站",
            bigText = "$stopName 預計 $arrivalClock 到站$following。$direction$distance" +
                "你常在 $usualClock 左右查看這條路線。$lapseNotice",
        )
    }

    /** How long after posting a reminder stops being true, and should clear itself. */
    fun timeoutMs(decision: SmartEtaDecision): Long =
        (decision.etaSeconds + POST_ARRIVAL_LINGER_SECONDS) * 1000L

    fun formatDistance(distanceMeters: Double): String {
        if (distanceMeters < 1000) {
            return "${distanceMeters.toInt()}m"
        }
        return String.format(Locale.US, "%.1fkm", distanceMeters / 1000.0)
    }

    private fun isOutdated(updatedAt: Long?, nowMs: Long): Boolean {
        val updatedAtMs = when {
            updatedAt == null -> return false
            updatedAt > 1_000_000_000_000L -> updatedAt
            updatedAt > 1_000_000_000L -> updatedAt * 1000
            else -> return false
        }
        return nowMs - updatedAtMs > MAX_FEED_AGE_MS
    }

    private fun etaMinutes(seconds: Int): Int = max(1, (seconds / 60.0).roundToInt())

    private fun formatClock(timeMs: Long, zone: TimeZone): String {
        val calendar = Calendar.getInstance(zone).apply { timeInMillis = timeMs }
        return formatMinuteOfDay(
            calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE),
        )
    }

    private fun formatMinuteOfDay(minute: Int): String =
        "${(minute / 60).toString().padStart(2, '0')}:${(minute % 60).toString().padStart(2, '0')}"

    private fun JsonElement?.asText(): String? {
        val primitive = this as? JsonPrimitive ?: return null
        if (primitive is JsonNull) {
            return null
        }
        return primitive.content.trim()
            .takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
    }

    private fun JsonElement?.asLong(): Long? =
        asText()?.let { it.toLongOrNull() ?: it.toDoubleOrNull()?.toLong() }

    private fun JsonElement?.asInt(): Int? = asLong()?.toInt()
}
