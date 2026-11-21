package tw.avianjay.taiwanbus.flutter

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.location.Location
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import java.io.File
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import java.util.concurrent.TimeUnit
import org.json.JSONObject

class SmartRouteNotificationWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        return try {
            SmartRouteNotificationSupport.ensureChannel(applicationContext)

            val settings = SmartRouteNotificationSupport.loadSettings(applicationContext)
                ?: return Result.success()
            if (!settings.enableNotifications) {
                return Result.success()
            }
            if (!SmartRouteNotificationSupport.canPostNotifications(applicationContext)) {
                return Result.success()
            }
            if (AppRuntimeStateStore.isAppInForeground(applicationContext)) {
                return Result.success()
            }

            // When to remind, and about what, was worked out by the app the
            // last time it was used. This only has to follow it.
            val plan = SmartRouteNotificationSupport.loadPlan(applicationContext)
                ?: return Result.success()
            val now = System.currentTimeMillis()
            if (!SmartRouteReminderRules.hasLiveSlots(plan, now)) {
                // Every habit in the plan has lapsed. Nothing can fire until
                // the app is opened and writes a new one, which reschedules —
                // unless it already has, which this checks under the lock.
                SmartRouteNotificationScheduler.cancelIfNothingLive(applicationContext)
                return Result.success()
            }
            val dueSlots = SmartRouteReminderRules.dueSlots(plan, settings.provider, now)
            if (dueSlots.isEmpty()) {
                return Result.success()
            }

            val clock = SmartRouteReminderRules.serviceClock(now, plan.dayStartHour)
            val history = SmartRouteNotificationSupport.loadHistory(applicationContext)
            if (!SmartRouteReminderRules.mayRemind(history, now, clock.day)) {
                return Result.success()
            }

            var activePlan = plan
            var activeNow = now
            var activeClock = clock
            var activeHistory = history
            var candidates = dueSlots
            val attempted = mutableSetOf<Pair<Int, Int>>()

            // Asked for at most once, and only once a slot has got this far:
            // a fix costs battery, and most runs end before needing one.
            val currentLocation by lazy {
                SmartRouteNotificationSupport.loadCurrentLocation(applicationContext)
            }
            while (true) {
                val slot = candidates.firstOrNull {
                    attempted.add(it.routeKey to it.pathId)
                } ?: break
                if (SmartRouteReminderRules.wasSeenForWindow(
                        slot,
                        activeNow,
                        activeClock.minute,
                    )
                ) continue
                val lastForRoute = SmartRouteNotificationSupport.loadLastReminderForRoute(
                    applicationContext,
                    slot,
                )
                if (!SmartRouteReminderRules.mayRemindRoute(lastForRoute, activeNow)) continue
                val routeData = SmartRouteNotificationSupport.loadRouteData(
                    applicationContext,
                    slot,
                ) ?: continue
                val choice = SmartRouteNotificationSupport.chooseStop(
                    slot = slot,
                    routeData = routeData,
                    location = currentLocation,
                ) ?: continue
                val liveStop = SmartRouteNotificationSupport.fetchLiveStop(
                    routeId = slot.routeId,
                    pathId = slot.pathId,
                    rawStopId = choice.stop.rawStopId,
                ) ?: continue
                val decision = SmartRouteReminderRules.decide(liveStop, choice.distanceMeters)
                    ?: continue

                val shown = SmartRouteNotificationSupport.remind(
                    context = applicationContext,
                    slot = slot,
                    stop = choice.stop,
                    text = { current ->
                        SmartRouteReminderRules.buildText(
                            routeName = current.routeName,
                            pathName = routeData.pathName,
                            stopName = choice.stop.stopName,
                            decision = decision,
                            distanceMeters = choice.distanceMeters,
                            slot = current,
                            dayStartHour = activePlan.dayStartHour,
                            // The arrival time is counted from when the feed
                            // was read, which is what its seconds are as of.
                            nowMs = liveStop.asOfMs,
                        )
                    },
                    timeoutMs = SmartRouteReminderRules.timeoutMs(decision),
                    history = SmartRouteReminderRules.afterReminder(
                        activeHistory,
                        activeNow,
                        activeClock.day,
                    ),
                    nowMs = activeNow,
                    checkedAtMs = System.currentTimeMillis(),
                )
                if (shown) break

                // A route can stop being due while its feed is in flight. A
                // different candidate may still be valid, but foreground and
                // channel checks are global and must stop the whole run.
                if (AppRuntimeStateStore.isAppInForeground(applicationContext) ||
                    !SmartRouteNotificationSupport.canPostNotifications(applicationContext)
                ) {
                    break
                }
                val refreshedPlan = SmartRouteNotificationSupport.loadPlan(applicationContext)
                    ?: break
                val refreshedNow = System.currentTimeMillis()
                val refreshedHistory = SmartRouteNotificationSupport.loadHistory(
                    applicationContext,
                )
                val refreshedCandidates =
                    SmartRouteReminderRules.dueSlotsAfterCandidateFailure(
                        plan = refreshedPlan,
                        provider = settings.provider,
                        nowMs = refreshedNow,
                        history = refreshedHistory,
                        attempted = attempted,
                    )
                activePlan = refreshedPlan
                activeNow = refreshedNow
                activeClock = SmartRouteReminderRules.serviceClock(
                    refreshedNow,
                    refreshedPlan.dayStartHour,
                )
                activeHistory = refreshedHistory
                candidates = refreshedCandidates
            }
            Result.success()
        } catch (_: Exception) {
            // Everything that can fail for a passing reason — the network, a
            // database mid-download — is already handled where it happens, so
            // what reaches here would fail the same way on a retry. The next
            // period runs regardless.
            Result.failure()
        }
    }
}

internal object SmartRouteNotificationSupport {
    private const val FLUTTER_PREFERENCES_NAME = "FlutterSharedPreferences"
    private const val SETTINGS_KEY = "flutter.app_settings"
    private const val SETTINGS_FALLBACK_KEY = "app_settings"

    // Written by StorageService.saveSmartRoutePlan on the Flutter side.
    private const val PLAN_KEY = "flutter.smart_route_plan"
    private const val NOTIFICATION_PREFERENCES_NAME = "smart_route_notifications"
    private const val LAST_REMINDER_KEY = "last_reminder_ms"
    private const val REMINDER_DAY_KEY = "reminder_day"
    private const val REMINDER_COUNT_KEY = "reminder_count"
    private const val LAST_ROUTE_REMINDER_KEY_PREFIX = "last_route_reminder_"
    private const val REMINDER_LOG_KEY = "reminder_log"
    internal const val CHANNEL_ID = "smart_route_recommendation"
    private const val CHANNEL_NAME = "智慧推薦提醒"
    private const val CHANNEL_DESCRIPTION =
        "在你常查看某條路線的時間點附近，依常用或最近站牌的到站時間主動提醒。"
    private const val NOTIFICATION_ID_BASE = 710_000
    private const val ROUTE_REQUEST_TIMEOUT_MS = 10_000
    private const val API_BASE_URL = "https://bus.avianjay.sbs"

    // BusRepository keeps its databases in this directory, under the path
    // sqflite's getDatabasesPath() returns: stops per provider in one file,
    // route and direction names for every provider in another.
    private const val DATABASE_DIRECTORY = ".yabus_backend"
    private val METADATA_DATABASE_NAMES = listOf(
        "routes_metadata_v1.sqlite",
        "routes_metadata_v2.sqlite",
    )

    // A fix older than this may be from wherever the phone last had a map
    // open, which is no guide to which stop its owner is near now.
    private const val MAX_LOCATION_AGE_MS = 10 * 60 * 1000L

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(true)
                enableVibration(true)
            },
        )
    }

    fun loadSettings(context: Context): SmartRouteSettings? {
        val preferences = flutterPreferences(context)
        val raw = preferences.getString(SETTINGS_KEY, null)
            ?: preferences.getString(SETTINGS_FALLBACK_KEY, null)
            ?: return null
        val root = try {
            JSONObject(raw)
        } catch (_: Exception) {
            return null
        }
        return SmartRouteSettings(
            provider = root.optString("provider", "twn"),
            enableNotifications = root.optBoolean("enableSmartRouteNotifications", false),
        )
    }

    fun loadPlan(context: Context): SmartRoutePlan? =
        SmartRouteReminderRules.parsePlan(
            flutterPreferences(context).getString(PLAN_KEY, null),
        )

    fun loadHistory(context: Context): SmartReminderHistory {
        val preferences = notificationPreferences(context)
        return SmartReminderHistory(
            lastAnyMs = preferences.getLong(LAST_REMINDER_KEY, 0L),
            countDay = preferences.getLong(REMINDER_DAY_KEY, 0L),
            countThatDay = preferences.getInt(REMINDER_COUNT_KEY, 0),
        )
    }

    fun loadLastReminderForRoute(context: Context, slot: SmartPlanSlot): Long =
        notificationPreferences(context).getLong(routeReminderKey(slot), 0L)

    fun saveReminder(
        context: Context,
        slot: SmartPlanSlot,
        history: SmartReminderHistory,
        nowMs: Long,
    ) {
        val preferences = notificationPreferences(context)
        preferences
            .edit()
            .putLong(LAST_REMINDER_KEY, history.lastAnyMs)
            .putLong(REMINDER_DAY_KEY, history.countDay)
            .putInt(REMINDER_COUNT_KEY, history.countThatDay)
            .putLong(routeReminderKey(slot), nowMs)
            .putString(
                REMINDER_LOG_KEY,
                SmartRouteReminderRules.appendToReminderLog(
                    preferences.getString(REMINDER_LOG_KEY, null),
                    slot,
                    nowMs,
                ),
            )
            .apply()
    }

    /** The reminders shown so far, as JSON, for the Flutter side to read. */
    fun loadReminderLog(context: Context): String =
        notificationPreferences(context).getString(REMINDER_LOG_KEY, null) ?: "[]"

    /**
     * Shows a reminder for [slot] and records it, against the limits and in
     * the log the Flutter side learns from — if it can still go out, and be
     * seen, at [checkedAtMs].
     *
     * A run reads the plan once and then waits on the location and the
     * network, and the app can replace the plan meanwhile: the rider clears
     * what it learned, or opens the route. So the plan is read again here,
     * and only what it says now goes out; see [SmartRouteReminderRules.stillDue].
     * [text] is written for the slot as that plan has it.
     *
     * One that cannot be seen — this channel turned off while the app's
     * other notifications stay on — is recorded nowhere. The habit model
     * reads a logged reminder as one that told the rider what they would
     * have opened the route for, and one nobody saw would excuse a day they
     * simply did not go.
     *
     * Returns whether it was shown.
     */
    fun remind(
        context: Context,
        slot: SmartPlanSlot,
        stop: SmartRouteStop,
        text: (SmartPlanSlot) -> SmartReminderText,
        timeoutMs: Long,
        history: SmartReminderHistory,
        nowMs: Long,
        checkedAtMs: Long,
    ): Boolean {
        val current = SmartRouteReminderRules.stillDue(loadPlan(context), slot, checkedAtMs)
            ?: return false
        // Opened while this run waited: the rider is looking at the app.
        if (AppRuntimeStateStore.isAppInForeground(context)) {
            return false
        }
        if (!canPostNotifications(context)) {
            return false
        }
        showNotification(context, current, stop, text(current), timeoutMs)
        saveReminder(context, current, history, nowMs)
        return true
    }

    /**
     * Drops every trace of reminders already shown: the log, and what holds
     * the next one back. For when the rider clears what the app has learned
     * about them, which this is part of.
     */
    fun forgetReminders(context: Context) {
        notificationPreferences(context).edit().clear().apply()
    }

    private fun routeReminderKey(slot: SmartPlanSlot): String =
        LAST_ROUTE_REMINDER_KEY_PREFIX +
            listOf(slot.provider, slot.routeKey, slot.pathId).joinToString("_")

    /**
     * The device's location, or null when it may not be read in the
     * background or no recent fix can be had. A reminder can still go out
     * without one, as long as the plan names the rider's usual stop.
     */
    fun loadCurrentLocation(context: Context): Location? {
        if (!hasLocationPermission(context)) {
            return null
        }

        return try {
            val client = LocationServices.getFusedLocationProviderClient(context)
            val lastKnown = try {
                Tasks.await(client.lastLocation, 5, TimeUnit.SECONDS)
            } catch (_: Exception) {
                null
            }
            if (lastKnown != null && isRecent(lastKnown)) {
                return lastKnown
            }

            val tokenSource = CancellationTokenSource()
            Tasks.await(
                client.getCurrentLocation(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    tokenSource.token,
                ),
                8,
                TimeUnit.SECONDS,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun isRecent(location: Location): Boolean {
        val ageMs =
            (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
        return ageMs <= MAX_LOCATION_AGE_MS
    }

    /**
     * The stops of the slot's direction, and that direction's name.
     *
     * Null when the stops cannot be read — the provider's database is not
     * downloaded, or is being replaced — which is not an error: there is
     * simply nothing to remind about until it is back.
     */
    fun loadRouteData(context: Context, slot: SmartPlanSlot): SmartRouteData? {
        val stops = queryDatabase(context, listOf("bus_${slot.provider}_v2.sqlite")) { database ->
            loadStops(database, slot.routeId, slot.pathId)
        }
        if (stops.isNullOrEmpty()) {
            return null
        }
        return SmartRouteData(
            // The name only labels the reminder, so doing without is fine.
            pathName = queryDatabase(context, METADATA_DATABASE_NAMES) { database ->
                loadPathName(database, slot.routeId, slot.pathId)
            },
            stops = stops,
        )
    }

    internal fun loadStops(
        database: SQLiteDatabase,
        routeId: String,
        pathId: Int,
    ): List<SmartRouteStop> {
        val result = mutableListOf<SmartRouteStop>()
        database.rawQuery(
            """
            SELECT stopid, name, seq, lon, lat
            FROM stops
            WHERE routeid = ? AND pathid = ?
            ORDER BY seq ASC
            """.trimIndent(),
            arrayOf(routeId, pathId.toString()),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val rawStopId = cursor.getString(0)?.trim().orEmpty()
                if (rawStopId.isEmpty()) {
                    continue
                }
                result += SmartRouteStop(
                    pathId = pathId,
                    rawStopId = rawStopId,
                    stopName = cursor.getString(1).orEmpty(),
                    sequence = cursor.getInt(2),
                    lon = cursor.getDouble(3),
                    lat = cursor.getDouble(4),
                )
            }
        }
        return result
    }

    internal fun loadPathName(database: SQLiteDatabase, routeId: String, pathId: Int): String? =
        database.rawQuery(
            "SELECT name FROM paths WHERE routeid = ? AND pathid = ? LIMIT 1",
            arrayOf(routeId, pathId.toString()),
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(0)?.trim()?.takeIf { it.isNotEmpty() }
            } else {
                null
            }
        }

    /**
     * Runs [query] against the first of [fileNames] that exists, read-only.
     * Null if none does or the query cannot be answered.
     */
    private fun <T> queryDatabase(
        context: Context,
        fileNames: List<String>,
        query: (SQLiteDatabase) -> T?,
    ): T? {
        val file = databaseDirectories(context)
            .flatMap { directory -> fileNames.map { File(directory, it) } }
            .firstOrNull { it.exists() }
            ?: return null
        val database = try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (_: Exception) {
            return null
        }
        return try {
            query(database)
        } catch (_: Exception) {
            // A schema this build does not know, or a file caught halfway
            // through being replaced by a database update.
            null
        } finally {
            runCatching { database.close() }
        }
    }

    private fun databaseDirectories(context: Context): List<File> = listOfNotNull(
        // Where the app keeps them now.
        context.getDatabasePath("_").parentFile?.let { File(it, DATABASE_DIRECTORY) },
        // Where it kept them before it moved them there.
        context.filesDir.parentFile?.let { File(it, "app_flutter/$DATABASE_DIRECTORY") },
        File(context.filesDir, DATABASE_DIRECTORY),
    )

    /** Measures what can be measured and leaves the choice to the rules. */
    fun chooseStop(
        slot: SmartPlanSlot,
        routeData: SmartRouteData,
        location: Location?,
    ): SmartStopChoice? {
        val usualStop = SmartRouteReminderRules.findUsualStop(slot, routeData.stops)
        var nearestStop: SmartRouteStop? = null
        var nearestDistance: Double? = null
        if (location != null) {
            for (stop in routeData.stops) {
                val distance = distanceMeters(location, stop) ?: continue
                if (nearestDistance == null || distance < nearestDistance) {
                    nearestDistance = distance
                    nearestStop = stop
                }
            }
        }
        return SmartRouteReminderRules.chooseStop(
            usualStop = usualStop,
            usualDistanceMeters = if (usualStop != null && location != null) {
                distanceMeters(location, usualStop)
            } else {
                null
            },
            nearestStop = nearestStop,
            nearestDistanceMeters = nearestDistance,
        )
    }

    private fun distanceMeters(location: Location, stop: SmartRouteStop): Double? {
        if (stop.lat == 0.0 || stop.lon == 0.0) {
            return null
        }
        val results = FloatArray(1)
        Location.distanceBetween(
            location.latitude,
            location.longitude,
            stop.lat,
            stop.lon,
            results,
        )
        return results[0].toDouble()
    }

    /**
     * The live state of one stop, counted down to the moment the response
     * arrived; see [SmartRouteReminderRules.parseLiveStop].
     */
    fun fetchLiveStop(
        routeId: String,
        pathId: Int,
        rawStopId: String,
    ): SmartLiveStop? {
        val encodedRouteId = URLEncoder.encode(routeId, Charsets.UTF_8.name())
        val connection = try {
            URL("$API_BASE_URL/api/v1/routes/$encodedRouteId/realtime")
                .openConnection() as HttpURLConnection
        } catch (_: Exception) {
            return null
        }
        connection.connectTimeout = ROUTE_REQUEST_TIMEOUT_MS
        connection.readTimeout = ROUTE_REQUEST_TIMEOUT_MS
        connection.requestMethod = "GET"
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("User-Agent", NativeApiUserAgent.value())
        connection.doInput = true
        connection.useCaches = false

        return try {
            if (connection.responseCode !in 200..299) {
                null
            } else {
                val jsonText = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                    reader.readText()
                }
                SmartRouteReminderRules.parseLiveStop(
                    jsonText,
                    pathId,
                    rawStopId,
                    System.currentTimeMillis(),
                )
            }
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }

    /**
     * Posts the reminder. Whether it will be seen is for the caller to have
     * checked; see [remind].
     */
    fun showNotification(
        context: Context,
        slot: SmartPlanSlot,
        stop: SmartRouteStop,
        text: SmartReminderText,
        timeoutMs: Long,
    ) {
        val contentIntent = PendingIntent.getActivity(
            context,
            slot.routeKey * 31 + slot.pathId,
            AppLaunchConstants.createRouteDetailIntent(
                context = context,
                provider = slot.provider,
                routeKey = slot.routeKey,
                routeId = slot.routeId,
                pathId = slot.pathId,
                // Use the selected stop, not the plan's usual stop: location
                // can pick a different one. Flutter needs the full-width id.
                stopId = launchStopId(stop.rawStopId).takeIf { it > 0L },
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_bus)
            .setContentTitle(text.title)
            .setContentText(text.text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text.bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            // Once the bus has gone the reminder is wrong, and a wrong arrival
            // time is worse than none: it takes itself down.
            .setTimeoutAfter(timeoutMs)
            .build()

        NotificationManagerCompat.from(context).notify(
            NOTIFICATION_ID_BASE + slot.routeKey % 100_000,
            notification,
        )
    }

    /**
     * Whether a reminder posted now would be shown: notifications allowed
     * for the app, and this channel not turned off on its own. With the
     * channel off the system drops the reminder without a word.
     */
    fun canPostNotifications(context: Context): Boolean {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL_ID)?.importance ==
            NotificationManager.IMPORTANCE_NONE
        ) {
            return false
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasLocationPermission(context: Context): Boolean {
        val hasFine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasFine && !hasCoarse) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val hasBackground = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
            if (!hasBackground) {
                return false
            }
        }
        return true
    }

    private fun flutterPreferences(context: Context): SharedPreferences =
        context.getSharedPreferences(FLUTTER_PREFERENCES_NAME, Context.MODE_PRIVATE)

    private fun notificationPreferences(context: Context): SharedPreferences =
        context.getSharedPreferences(NOTIFICATION_PREFERENCES_NAME, Context.MODE_PRIVATE)
}

internal data class SmartRouteSettings(
    val provider: String,
    val enableNotifications: Boolean,
)

internal data class SmartRouteData(
    val pathName: String?,
    /** The stops of one direction, in running order. */
    val stops: List<SmartRouteStop>,
)
