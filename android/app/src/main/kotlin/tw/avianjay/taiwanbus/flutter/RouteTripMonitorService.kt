package tw.avianjay.taiwanbus.flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.drawable.Icon
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.abs
import org.json.JSONArray
import org.json.JSONObject

internal fun buildOnboardTripSubText(nearestStopName: String): String =
    "已上車 · 最近站牌 $nearestStopName"

class RouteTripMonitorService : Service() {
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var notificationManager: NotificationManagerCompat
    private val refreshLock = Any()
    private val familyRealtime = TripMonitorFamilyRealtime(::fetchBackendJson)

    @Volatile
    private var session: TrackingSession? = null
    private var appInForeground = true
    private var foregroundStarted = false
    private var latestLocation: Location? = null

    /**
     * Owns the "is the user on the bus" question. It is fed the user's own fixes
     * and the live vehicle positions, and never looks at whether the app is in
     * the foreground — a trip does not stop being a trip when the user opens
     * the app.
     */
    private var detector: TripRideDetector? = null
    private var latestRide = RideSnapshot()
    private val detectorLock = Any()
    /** Under detectorLock: newer app-provided stop data supersedes pending stop requests. */
    private var stopFeedRevision = 0L
    private var boardingAlertSent = false
    private var boardingCheckNotificationId = 0L
    private var destinationSetupPromptSent = false
    private var arrivalDetectedAtMs = 0L
    private var destinationAlertStage = 0
    private var overshootAlertSent = false
    private var lastWentBackgroundAtMs = 0L
    private var refreshInFlight = false
    private var refreshPending = false
    private var lastRefreshStartedAtMs = 0L
    private var cachedLiveRouteIds: List<String> = emptyList()
    private var cachedLivePathId: Int? = null
    private var cachedLiveFetchedAtMs = 0L
    private var cachedLiveStops: Map<Int, LiveStopState> = emptyMap()
    /** Under refreshLock: every family route shares the same polling policy. */
    private val busFeedRefreshByRoute = mutableMapOf<String, BusFeedRefresh>()
    private var liveStopBackoffUntilMs = 0L
    private var wakeLock: PowerManager.WakeLock? = null

    private val pollingRunnable = object : Runnable {
        override fun run() {
            if (!foregroundStarted) {
                return
            }
            // Refresh in the foreground too: the notification, the ETA text and
            // the boarding question all depend on this loop, and skipping it
            // while the app is open was why boarding went unnoticed.
            refreshNotification()
            mainHandler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(locationResult: LocationResult) {
            val location = locationResult.lastLocation ?: return
            latestLocation = location
            onUserLocation(location)
            refreshNotification()
        }
    }

    private fun onUserLocation(location: Location): Unit = synchronized(detectorLock) {
        val currentDetector = detector ?: return
        currentDetector.onUserLocation(
            RideGeoPoint(
                latitude = location.latitude,
                longitude = location.longitude,
                // The fix's real age, so that a cached one from minutes ago is
                // recognised as stale instead of passing for the present.
                timestampMs = rideFixTimestampMs(location),
                accuracyMeters = if (location.hasAccuracy()) location.accuracy else 0f,
                speedMetersPerSecond = location.speed.takeIf { location.hasSpeed() && it > 0f },
            ),
        )
    }

    override fun onCreate() {
        super.onCreate()
        notificationManager = NotificationManagerCompat.from(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Fulfil the foreground-service deadline before parsing the route,
        // reading preferences, initializing Play Services or building OEM extras.
        // A queued start can reach this instance after a stop, so do this for
        // every start command, not just in onCreate().
        if (intent?.action == ACTION_START_OR_UPDATE || intent?.action == null) {
            if (!ensureForegroundStarted()) {
                stopTracking()
                return START_NOT_STICKY
            }
        }
        if (intent == null || intent.action == null) {
            // A sticky restart has no persisted session to restore.
            stopTracking()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_STOP -> {
                AppRuntimeStateStore.clearPausedTripMonitor(this)
                stopTracking()
                return START_NOT_STICKY
            }

            ACTION_PAUSE -> {
                val reason = intent.getStringExtra(EXTRA_PAUSE_REASON)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: PAUSE_REASON_USER
                val explicitSession = intent.getStringExtra(EXTRA_SESSION_JSON)?.let(::parseSessionJson)
                pauseTracking(reason, explicitSession)
                return START_NOT_STICKY
            }

            ACTION_SET_APP_FOREGROUND -> {
                appInForeground = intent.getBooleanExtra(EXTRA_APP_IN_FOREGROUND, true)
                lastWentBackgroundAtMs = if (appInForeground) {
                    0L
                } else {
                    System.currentTimeMillis()
                }
                AppRuntimeStateStore.setAppInForeground(this, appInForeground)
                if (session == null) {
                    stopTracking()
                    return START_NOT_STICKY
                }
                refreshNotification(force = true)
                startPolling()
                return START_STICKY
            }

            ACTION_RESUME -> {
                AppRuntimeStateStore.clearPausedTripMonitor(this)
                if (session == null) {
                    // Started solely to clear the paused flag — nothing to keep
                    // running until the next startOrUpdate arrives.
                    stopSelf()
                }
                return START_NOT_STICKY
            }

            ACTION_MARK_BOARDED -> {
                if (session == null) {
                    stopTracking()
                    return START_NOT_STICKY
                }
                val now = System.currentTimeMillis()
                synchronized(detectorLock) {
                    detector?.confirmBoardedByUser(now)
                    latestRide = detector?.snapshot(now) ?: RideSnapshot()
                }
                boardingAlertSent = true
                cancelBoardingCheckPrompt()
                refreshNotification(force = true)
                return START_STICKY
            }

            ACTION_NOT_BOARDED -> {
                if (session == null) {
                    stopTracking()
                    return START_NOT_STICKY
                }
                val now = System.currentTimeMillis()
                synchronized(detectorLock) {
                    // Only the bus that was asked about is set aside; the next
                    // one still gets detected and asked about in its turn.
                    detector?.declineBoarding(now)
                    latestRide = detector?.snapshot(now) ?: RideSnapshot()
                }
                boardingAlertSent = false
                destinationSetupPromptSent = false
                arrivalDetectedAtMs = 0L
                destinationAlertStage = 0
                overshootAlertSent = false
                cancelBoardingCheckPrompt()
                refreshNotification(force = true)
                return START_STICKY
            }

            ACTION_START_OR_UPDATE -> {
                val sessionJson = intent.getStringExtra(EXTRA_SESSION_JSON)
                val parsedSession = sessionJson?.let(::parseSessionJson)
                if (parsedSession == null) {
                    stopTracking()
                    return START_NOT_STICKY
                }

                val previousDestination = session?.destinationStopId
                val previousBoarding = session?.boardingStopId
                val previousRouteId = session?.routeId
                val previousRouteKey = session?.routeKey
                val previousPathId = session?.pathId
                val previousStopIds = session?.stops?.map { it.stopId }
                val previousFamily = session?.realtimeRouteIds?.toSet()
                val hadSession = session != null
                val hadDetector = session != null && detectorExists()
                if (AppRuntimeStateStore.isTripMonitorPausedFor(this, parsedSession)) {
                    appInForeground = parsedSession.appInForeground
                    stopTracking()
                    return START_NOT_STICKY
                }
                val startedAtMs = System.currentTimeMillis()
                val continuesBoardedRide = !hadDetector && continuesBoardedRide(
                    paused = AppRuntimeStateStore.loadPausedTripMonitor(this),
                    session = parsedSession,
                    nowMs = startedAtMs,
                )
                appInForeground = parsedSession.appInForeground
                val providedStops = parsedSession.stops.mapNotNull { stop ->
                    stop.liveData?.let { stop.stopId to it }
                }.toMap()
                if (!appInForeground && lastWentBackgroundAtMs == 0L) {
                    lastWentBackgroundAtMs = System.currentTimeMillis()
                }
                AppRuntimeStateStore.setAppInForeground(this, appInForeground)
                val tripOriginChanged =
                    previousBoarding != parsedSession.boardingStopId ||
                        previousRouteId != parsedSession.routeId ||
                        // Some providers leave routeId blank, so the route key
                        // is what actually tells two routes apart.
                        previousRouteKey != parsedSession.routeKey ||
                        // The other direction of the same route can share a
                        // boarding stop, yet it is another line of stops: the
                        // detector measures everything along the one it was
                        // built with.
                        previousPathId != parsedSession.pathId ||
                        previousStopIds != parsedSession.stops.map { it.stopId }
                val destinationChanged =
                    previousDestination != parsedSession.destinationStopId
                val familyChanged = previousFamily != parsedSession.realtimeRouteIds.toSet()
                // A preliminary primary-route response must not keep a waiting
                // reminder locked to that bus once the family arrives, and the
                // detector must exist before anything can consult it. A ride the
                // user already confirmed is never rebuilt out from under them.
                val rideAlreadyConfirmed = currentRideSnapshot().hasBoarded
                val startsNewTrip = tripOriginChanged ||
                    (familyChanged && !rideAlreadyConfirmed) ||
                    !hadDetector
                if (startsNewTrip) {
                    boardingAlertSent = false
                    destinationSetupPromptSent = false
                    arrivalDetectedAtMs = 0L
                    destinationAlertStage = 0
                    overshootAlertSent = false
                    cancelBoardingCheckPrompt()
                } else if (destinationChanged) {
                    // Choosing a destination after boarding must not unlock the
                    // current vehicle and fall back to the next bus at the
                    // boarding stop. Only the destination alert lifecycle is new.
                    destinationSetupPromptSent = false
                    arrivalDetectedAtMs = 0L
                    destinationAlertStage = 0
                    overshootAlertSent = false
                }
                // The session and the detector built for it change hands in one
                // step: a refresh still fetching for the previous trip looks
                // for exactly this before it applies what it brought back.
                synchronized(detectorLock) {
                    session = parsedSession
                    val tracking = if (startsNewTrip) {
                        createDetector(parsedSession).also { created ->
                            if (continuesBoardedRide) {
                                // Choosing where to get off, in answer to "you
                                // have boarded", is the rider confirming it.
                                created.confirmBoardedByUser(startedAtMs)
                            }
                            detector = created
                            latestRide = RideSnapshot()
                            // It starts knowing nothing, so both feeds are due
                            // at once, and the last trip's failures are not its
                            // own to sit out.
                            forgetLiveFeeds()
                        }
                    } else {
                        if (familyChanged) {
                            synchronized(refreshLock) {
                                busFeedRefreshByRoute.keys.retainAll(parsedSession.realtimeRouteIds.toSet())
                            }
                        }
                        detector?.also { it.updateDestination(parsedSession.destinationStopId) }
                    }
                    if (providedStops.isNotEmpty()) {
                        stopFeedRevision++
                        synchronized(refreshLock) {
                            cachedLiveRouteIds = parsedSession.realtimeRouteIds
                            cachedLivePathId = parsedSession.pathId
                            cachedLiveFetchedAtMs = SystemClock.elapsedRealtime()
                            cachedLiveStops = providedStops
                        }
                        // While the app is open it does the fetching, and this is
                        // all the detector hears of the boarding stop's ETA.
                        tracking?.let { feedBoardingEta(it, parsedSession, providedStops) }
                    }
                }
                if (startsNewTrip) {
                    if (continuesBoardedRide) {
                        boardingAlertSent = true
                        AppRuntimeStateStore.clearPausedTripMonitor(this)
                    }
                    refreshRideSnapshot(System.currentTimeMillis())
                    // Only the very first update seeds the detector from the
                    // session's stale position; a later re-seed would replay an
                    // old fix as if it were current.
                    if (!hadSession) {
                        latestLocation = createSessionLocation(parsedSession) ?: latestLocation
                        latestLocation?.let(::onUserLocation)
                    }
                }

                createAlertNotificationChannel()
                requestLocationUpdates()
                acquireWakeLock()
                refreshNotification(force = true)
                startPolling()
            }
        }
        return START_STICKY
    }

    private fun detectorExists(): Boolean = synchronized(detectorLock) { detector != null }

    /** A trip as one refresh sees it: the session, and the detector built for it. */
    private class TrackedTrip(
        val session: TrackingSession,
        val detector: TripRideDetector,
        val stopFeedRevision: Long,
    )

    private data class BusFeedRefresh(
        val fetchedAtElapsedMs: Long? = null,
        val retryAtElapsedMs: Long = 0L,
    )

    private fun currentTrip(): TrackedTrip? = synchronized(detectorLock) {
        val currentSession = session ?: return null
        val currentDetector = detector ?: return null
        TrackedTrip(currentSession, currentDetector, stopFeedRevision)
    }

    /**
     * Applies what a request brought back for [trip], unless the trip has been
     * replaced while the request was out; returns whether it was applied.
     *
     * The rider can open another route, or the other direction, while a request
     * is in flight. The check and [apply] share the lock the detector is
     * replaced under, so what was fetched for one trip never lands in the next.
     */
    private fun applyToTrip(trip: TrackedTrip, apply: () -> Unit): Boolean =
        synchronized(detectorLock) {
            if (detector !== trip.detector) {
                return false
            }
            apply()
            true
        }

    /**
     * Runs [action] on the main thread unless by then [trackedSession] has been
     * replaced, or the ride has moved on from [ride] — the rider has answered
     * the boarding question, say. Sessions are only ever replaced on the main
     * thread and answers arrive there, so once the check has passed neither can
     * happen before [action] has run.
     */
    private fun postIfStillTracking(
        trackedSession: TrackingSession,
        ride: RideSnapshot? = null,
        action: () -> Unit,
    ) {
        mainHandler.post {
            if (session === trackedSession && (ride == null || currentRideSnapshot() === ride)) {
                action()
            }
        }
    }

    /**
     * Whether [session] is the ride that was paused for want of a destination,
     * now given one.
     *
     * On board with nowhere to get off there is nothing to remind the rider of,
     * so the monitor asks them to choose a stop and pauses. Their answer starts
     * it again — on the same bus. Coming back as "waiting to board" would throw
     * the ride away at the very moment the reminders it was chosen for become
     * possible, and mid-route there may be nothing left to detect it from.
     */
    private fun continuesBoardedRide(
        paused: TripMonitorPauseState?,
        session: TrackingSession,
        nowMs: Long,
    ): Boolean {
        paused ?: return false
        return paused.reason == PAUSE_REASON_BOARDED_NO_DESTINATION &&
            paused.destinationStopId == null &&
            session.destinationStopId != null &&
            paused.provider == session.provider &&
            paused.routeKey == session.routeKey &&
            paused.pathId == session.pathId &&
            paused.boardingStopId == session.boardingStopId &&
            nowMs - paused.pausedAtMs in 0L..BOARDED_RIDE_RESUME_WINDOW_MS
    }

    override fun onDestroy() {
        // A refresh still in flight has no trip left to apply itself to.
        synchronized(detectorLock) {
            session = null
            detector = null
        }
        mainHandler.removeCallbacksAndMessages(null)
        runCatching {
            if (::fusedLocationClient.isInitialized) {
                fusedLocationClient.removeLocationUpdates(locationCallback)
            }
        }
        releaseWakeLock()
        ioExecutor.shutdownNow()
        super.onDestroy()
    }

    /**
     * A partial wake lock for as long as a trip is being tracked.
     *
     * With the screen off and the phone still, the CPU suspends between wakeups
     * and the 15-second refresh loop stalls — the app cannot then tell "still
     * waiting at the stop" from "already on the bus". Holding this keeps the
     * loop and the detector's timers running for the length of the trip.
     *
     * This covers the idle/screen-off case. Deep Doze ignores wake locks
     * outright, so a phone that has been motionless for half an hour is still
     * at the mercy of the platform and the OEM; the lock is a mitigation, not
     * a guarantee.
     */
    private fun acquireWakeLock() {
        val manager = getSystemService(PowerManager::class.java) ?: return
        if (wakeLock?.isHeld == true) {
            return
        }
        val lock = runCatching {
            manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
        }.getOrNull() ?: return
        lock.setReferenceCounted(false)
        runCatching { lock.acquire(WAKE_LOCK_TIMEOUT_MS) }
        wakeLock = lock
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        wakeLock = null
        runCatching { if (lock.isHeld) lock.release() }
    }

    private fun buildStartupSnapshot(session: TrackingSession): TrackingSnapshot {
        val startupLocation = latestLocation ?: createSessionLocation(session)
        val nearestIndex = startupLocation?.let { location ->
            findNearestStopIndex(session.stops, location)
        } ?: -1
        val subTextParts = mutableListOf<String>()
        if (session.pathName.isNotBlank()) {
            subTextParts += session.pathName
        }
        session.boardingStopName?.takeIf { it.isNotBlank() }?.let { stopName ->
            subTextParts += "上車站 $stopName"
        }
        session.destinationStopName?.takeIf { it.isNotBlank() }?.let { stopName ->
            subTextParts += "下車站 $stopName"
        }
        val content = when {
            nearestIndex >= 0 -> "最近站牌 ${session.stops[nearestIndex].stopName}"
            session.destinationStopName?.isNotBlank() == true ->
                "已啓動 ${session.destinationStopName} 下車提醒"
            session.boardingStopName?.isNotBlank() == true ->
                "已啓動 ${session.boardingStopName} 乘車提醒"
            appInForeground -> "已啓動這條路線的乘車提醒"
            else -> "背景乘車提醒已啓動"
        }
        return TrackingSnapshot(
            title = session.routeName,
            content = content,
            subText = subTextParts.ifEmpty { listOf("背景乘車提醒已啓動") }.joinToString(" · "),
            progressMax = null,
            progressValue = null,
            shortCriticalText = null,
        )
    }

    private fun createSessionLocation(session: TrackingSession): Location? {
        return session.initialLatitude?.let { latitude ->
            session.initialLongitude?.let { longitude ->
                Location("trip_monitor_session").apply {
                    this.latitude = latitude
                    this.longitude = longitude
                    // The route screen's last position can be minutes old by
                    // the time the trip starts; carrying when it was taken lets
                    // the detector judge that for itself.
                    session.initialLocationTimestampMs?.let { time = it }
                }
            }
        }
    }

    private fun createDetector(session: TrackingSession): TripRideDetector {
        return TripRideDetector(
            stops = session.stops,
            pathId = session.pathId,
            boardingStopId = session.boardingStopId,
            destinationStopId = session.destinationStopId,
        )
    }

    private fun ensureForegroundStarted(): Boolean {
        if (foregroundStarted) {
            return true
        }
        return runCatching {
            createTrackingNotificationChannel()
            val notification = NotificationCompat.Builder(this, TRACKING_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_status_bus)
                .setContentTitle("YABus")
                .setContentText("正在啟動乘車提醒…")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
            startForegroundInternal(notification)
        }.getOrDefault(false)
    }

    private fun startForegroundInternal(notification: Notification): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    TRACKING_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(TRACKING_NOTIFICATION_ID, notification)
            }
            foregroundStarted = true
            true
        } catch (_: Exception) {
            // Android 12+ can reject the promotion (app judged background) and
            // Android 14+ throws SecurityException when the location grant no
            // longer allows a location-type foreground service. Both used to
            // crash the process right as the user switched back to the app —
            // degrade to stopping the monitor instead.
            foregroundStarted = false
            false
        }
    }

    private fun requestLocationUpdates() {
        // Detection needs the user's own track, so updates are requested
        // whenever any location permission is held. Requiring the "allow all
        // the time" grant here is what used to leave the whole boarding state
        // machine inert: a location-type foreground service started while the
        // app was visible keeps while-in-use access after it goes to the
        // background, so the stricter grant is not needed to keep tracking.
        if (!hasLocationPermission()) {
            return
        }
        if (!::fusedLocationClient.isInitialized) {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        }
        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            LOCATION_UPDATE_INTERVAL_MS,
        ).setMinUpdateIntervalMillis(LOCATION_MIN_UPDATE_INTERVAL_MS)
            // No distance filter: a phone waiting at the stop must keep
            // reporting, both so the app can tell the user is still there and
            // so a fix is ready the moment they board.
            .setMinUpdateDistanceMeters(0f)
            .setWaitForAccurateLocation(false)
            .build()

        runCatching {
            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback,
                Looper.getMainLooper(),
            )
        }
        runCatching {
            fusedLocationClient.lastLocation.addOnSuccessListener { location ->
                if (location != null) {
                    latestLocation = location
                    onUserLocation(location)
                    refreshNotification()
                }
            }
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun startPolling() {
        mainHandler.removeCallbacks(pollingRunnable)
        if (!foregroundStarted) {
            return
        }
        mainHandler.postDelayed(pollingRunnable, POLL_INTERVAL_MS)
    }

    private fun stopPolling() {
        mainHandler.removeCallbacks(pollingRunnable)
    }

    private fun refreshNotification(force: Boolean = false) {
        if (session == null) {
            return
        }
        synchronized(refreshLock) {
            val now = SystemClock.elapsedRealtime()
            if (refreshInFlight) {
                refreshPending = true
                return
            }
            if (
                !force &&
                lastRefreshStartedAtMs != 0L &&
                now - lastRefreshStartedAtMs < MIN_REFRESH_INTERVAL_MS
            ) {
                return
            }
            refreshInFlight = true
            lastRefreshStartedAtMs = now
        }
        val submitted = runCatching {
            ioExecutor.execute {
                try {
                    runCatching { refreshTrip(force) }
                } finally {
                    var shouldRefreshAgain = false
                    synchronized(refreshLock) {
                        refreshInFlight = false
                        if (refreshPending) {
                            refreshPending = false
                            shouldRefreshAgain = true
                        } else {
                            refreshPending = false
                        }
                    }
                    if (shouldRefreshAgain) {
                        mainHandler.postDelayed(
                            { refreshNotification() },
                            MIN_REFRESH_INTERVAL_MS,
                        )
                    }
                }
            }
        }.isSuccess
        if (!submitted) {
            // Executor already shut down (service destroyed mid-refresh).
            synchronized(refreshLock) {
                refreshInFlight = false
                refreshPending = false
            }
        }
    }

    /**
     * One refresh, on the IO thread: fetch, let the detector look again, and
     * hand what is to be shown and alerted to the main thread.
     *
     * The trip is read here rather than where the refresh was asked for, and is
     * checked again after every wait, because the main thread can replace it at
     * any moment.
     */
    private fun refreshTrip(force: Boolean) {
        val trip = currentTrip() ?: return
        val trackedSession = trip.session
        if (force) {
            // Rich notifications (including OEM integrations) are built off the
            // main thread, after foreground promotion.
            val startup = buildTrackingNotification(buildStartupSnapshot(trackedSession))
            postIfStillTracking(trackedSession) {
                notificationManager.notify(TRACKING_NOTIFICATION_ID, startup)
            }
        }
        // Fetched before the snapshot: everything the detector learns arrives
        // through here.
        if (!updateLiveData(trip)) {
            return
        }
        // Advanced on every refresh, not just when the bus feed came back,
        // because the question timing and the user's own progress move
        // independently of it.
        val ride = advanceRide(trip, System.currentTimeMillis()) ?: return
        val trackingSnapshot = buildSnapshot(
            trackedSession,
            latestLocation ?: createSessionLocation(trackedSession),
            ride,
        )
        val notification = buildTrackingNotification(trackingSnapshot)
        // Alerts can pause or stop the trip, so they are decided where trips
        // are replaced and the rider's answers arrive: one worked out for the
        // last trip, or from before "I am not on it", must not be acted on.
        postIfStillTracking(trackedSession, ride) {
            notificationManager.notify(TRACKING_NOTIFICATION_ID, notification)
            maybeSendTripAlerts(trackedSession, trackingSnapshot)
        }
    }

    /**
     * Pulls whatever the detector needs from the backend: the boarding stop's
     * ETA, and the live positions of every vehicle on the route.
     *
     * Both feeds share one rate-limit bucket with the rest of the app, so they
     * are throttled by age rather than fetched on every refresh, and a failed
     * request backs that endpoint off instead of hammering the server. Every
     * family route uses that same interval/back-off policy independently, so a
     * failed stop feed or variant does not silence healthy vehicle endpoints.
     *
     * Returns false when [trip] was replaced while a request was out; nothing
     * fetched after that point has been applied, and the caller should stop.
     */
    private fun updateLiveData(trip: TrackedTrip): Boolean {
        val session = trip.session
        val routeIds = session.realtimeRouteIds
        if (routeIds.isEmpty()) {
            return true
        }
        val nowElapsed = SystemClock.elapsedRealtime()
        val (wantsStops, busRouteIdsDue) = synchronized(refreshLock) {
            val stopsDue = nowElapsed >= liveStopBackoffUntilMs && (
                cachedLiveRouteIds != routeIds ||
                    cachedLivePathId != session.pathId ||
                    nowElapsed - cachedLiveFetchedAtMs >= LIVE_STOP_REFRESH_INTERVAL_MS
                )
            val busesDue = routeIds.filter { routeId ->
                val state = busFeedRefreshByRoute[routeId]
                state == null || (nowElapsed >= state.retryAtElapsedMs &&
                    (state.fetchedAtElapsedMs == null ||
                        nowElapsed - state.fetchedAtElapsedMs >= LIVE_BUS_REFRESH_INTERVAL_MS))
            }
            stopsDue to busesDue
        }

        if (wantsStops) {
            val liveStops = fetchLiveStopMapFromBackend(session)
            val stillTracked = applyToTrip(trip) {
                // The same detector can receive a newer foreground update while
                // this request is out. Discard its stop data and back-off only;
                // the independently fetched vehicle positions remain useful.
                if (stopFeedRevision != trip.stopFeedRevision) {
                    return@applyToTrip
                }
                // familyRealtime folds a failed request into an empty map, and a
                // route with stops to look up that answers with nothing is a
                // failure rather than an empty feed — so back off rather than
                // spend the shared rate limit on retries.
                if (liveStops.isEmpty()) {
                    synchronized(refreshLock) {
                        liveStopBackoffUntilMs = nowElapsed + LIVE_FETCH_BACKOFF_MS
                    }
                } else {
                    synchronized(refreshLock) {
                        cachedLiveRouteIds = routeIds
                        cachedLivePathId = session.pathId
                        cachedLiveFetchedAtMs = nowElapsed
                        cachedLiveStops = liveStops
                    }
                    feedBoardingEta(trip.detector, session, liveStops)
                }
            }
            if (!stillTracked) {
                return false
            }
        }

        val reportsByRoute = linkedMapOf<String, List<RideBusReport>>()
        for (routeId in busRouteIdsDue) {
            val reports = fetchBusReportsFromBackend(routeId)
            if (!applyToTrip(trip) {
                // A confirmed ride survives family updates, but an endpoint
                // removed from its family must not publish an in-flight result.
                if (routeId !in this.session?.realtimeRouteIds.orEmpty()) {
                    return@applyToTrip
                }
                synchronized(refreshLock) {
                    val receivedAt = SystemClock.elapsedRealtime()
                    busFeedRefreshByRoute[routeId] = if (reports == null) {
                        (busFeedRefreshByRoute[routeId] ?: BusFeedRefresh()).copy(
                            retryAtElapsedMs = receivedAt + LIVE_FETCH_BACKOFF_MS,
                        )
                    } else {
                        BusFeedRefresh(fetchedAtElapsedMs = receivedAt)
                    }
                }
                reports?.let { reportsByRoute[routeId] = it }
            }) {
                return false
            }
        }
        return applyToTrip(trip) {
            val currentRoutes = this.session?.realtimeRouteIds.orEmpty().toSet()
            // A plate can occur in more than one endpoint; it is still one bus.
            // Keep its newest report, rather than letting route iteration order
            // choose which position drives a ride with no phone location.
            val reports = reportsByRoute.filterKeys { it in currentRoutes }.values.flatten()
                .groupBy { it.vehicleId }.values.mapNotNull { track -> track.maxByOrNull { it.gpsTimeMs } }
            trip.detector.onBusReports(reports)
        }
    }

    private fun feedBoardingEta(
        target: TripRideDetector,
        session: TrackingSession,
        liveStops: Map<Int, LiveStopState>,
    ) {
        val boardingStopId = session.boardingStopId ?: return
        val liveStop = liveStops[boardingStopId] ?: return
        val etaEntry = liveStop.etaEntries.firstOrNull()
        // A plate on an ETA entry is a bus still on its way, possibly ten
        // minutes out; only a bus the feed places at the stop counts as here.
        val arriving = liveStop.seconds?.let { it <= 0 } == true ||
            liveStop.busesAtStop.isNotEmpty() ||
            liveStop.message?.contains("進站") == true ||
            liveStop.message?.contains("到站") == true
        val now = System.currentTimeMillis()
        synchronized(detectorLock) {
            target.onBoardingStopEta(
                etaSeconds = liveStop.seconds ?: etaEntry?.seconds,
                arriving = arriving,
                nowMs = now,
            )
        }
    }

    private fun refreshRideSnapshot(nowMs: Long) {
        synchronized(detectorLock) {
            latestRide = detector?.snapshot(nowMs) ?: RideSnapshot()
        }
    }

    /**
     * Lets [trip]'s detector look again and returns what it now makes of the
     * ride; null when the trip has been replaced.
     */
    private fun advanceRide(trip: TrackedTrip, nowMs: Long): RideSnapshot? = synchronized(detectorLock) {
        if (detector !== trip.detector) {
            return null
        }
        trip.detector.snapshot(nowMs).also { latestRide = it }
    }

    private fun currentRideSnapshot(): RideSnapshot = synchronized(detectorLock) { latestRide }

    /**
     * Builds the notification from the detector's view of the trip plus the
     * live stop feed. The detector owns every "where is the user in the trip"
     * decision; this only renders it.
     */
    private fun buildSnapshot(
        session: TrackingSession,
        location: Location?,
        ride: RideSnapshot,
    ): TrackingSnapshot {
        val liveStops = fetchLiveStopMap(session)
        if (this.session !== session) return buildStartupSnapshot(session)
        // A missing fix is not an early exit: the detector can still raise the
        // boarding question without any location at all, and the notification
        // is built from what it knows rather than from a nearest-stop guess.
        val nearestIndex = location?.let { findNearestStopIndex(session.stops, it) } ?: -1
        val nearestStop = session.stops.getOrNull(nearestIndex)
        val nearestLiveStop = nearestStop?.let { liveStops[it.stopId] }
        val nearestEtaText = displayEtaText(nearestLiveStop)
        val nearestStopDistanceMeters = if (location != null && nearestStop != null) {
            distanceMeters(location.latitude, location.longitude, nearestStop.lat, nearestStop.lon)
        } else {
            null
        }
        val destinationIndex = session.destinationStopId
            ?.let { id -> session.stops.indexOfFirst { it.stopId == id } }
            ?.takeIf { it >= 0 }
            ?: -1
        val destinationStop = session.stops.getOrNull(destinationIndex)
        val boardingIndex = ride.boardingStopIndex.takeIf { it >= 0 }
            ?: session.boardingStopId
                ?.let { id -> session.stops.indexOfFirst { it.stopId == id } }
                ?.takeIf { it >= 0 }
            ?: -1
        val boardingStop = session.stops.getOrNull(boardingIndex)

        val boardingLiveStop = boardingStop?.let { liveStops[it.stopId] }
        // Prefer the vehicle the detector is following; fall back to whatever
        // the stop-level feed says so the countdown still works where the ETA
        // entries carry no plate (雙北).
        val boardingVehicleId = ride.nextBusVehicleId
        val boardingEtaText = displayEtaText(boardingLiveStop, boardingVehicleId)
        val boardingEtaSeconds = resolveEtaSeconds(boardingLiveStop, boardingVehicleId)
        val boardingEtaShort = displayShortEtaText(boardingLiveStop, boardingVehicleId)
        val busStopsUntilBoarding = ride.busStopsUntilBoarding
        val busStopsAway = nearestIndex.takeIf { it >= 0 }?.let { index ->
            ride.trackedVehicleId?.let { tracked ->
                findTrackedBusIndex(
                    stops = session.stops,
                    liveStops = liveStops,
                    preferredVehicleId = tracked,
                )
            }?.let { (index - it).coerceAtLeast(0) }
        }

        if (ride.hasBoarded && destinationStop == null) {
            // On board with nowhere to get off yet. This comes before every
            // waiting branch — including the one for a trip with neither end
            // chosen — because a confirmed ride has to be reported as one:
            // that is what makes the destination-setup prompt fire.
            val travelIndex = ride.progressStopIndex.takeIf { it >= 0 }
                ?: ride.nearestStopIndexOnBoard(liveStops, session.stops)
                ?: nearestIndex
            val currentStop = session.stops.getOrNull(travelIndex)
            return TrackingSnapshot(
                title = session.routeName,
                content = if (currentStop != null) {
                    "已上車 · 最近站牌 ${currentStop.stopName}"
                } else {
                    "已上車 · 追蹤中"
                },
                subText = buildOnboardTripSubText(
                    currentStop?.stopName ?: session.pathName.ifBlank { "乘車中" },
                ),
                progressMax = null,
                progressValue = null,
                shortCriticalText = null,
                hasBoarded = true,
                boardingName = boardingStop?.stopName,
                boardingVehicleId = ride.trackedVehicleId ?: boardingVehicleId,
                nearestStopDistanceMeters = nearestStopDistanceMeters,
            )
        }

        if (boardingStop == null && destinationStop == null) {
            // Neither end of the trip is known: just report the nearest stop.
            return TrackingSnapshot(
                title = session.routeName,
                content = if (nearestStop != null) {
                    "${nearestStop.stopName} · $nearestEtaText"
                } else {
                    session.pathName.ifBlank { "乘車提醒進行中" }
                },
                subText = if (nearestStop != null) {
                    buildNearestStatusText(session, nearestStop, nearestEtaText, busStopsAway)
                } else {
                    session.pathName.ifBlank { "背景乘車提醒進行中" }
                },
                progressMax = null,
                progressValue = null,
                shortCriticalText = buildShortCriticalText(
                    busStopsAway,
                    displayShortEtaText(nearestLiveStop),
                ),
                nearestStopDistanceMeters = nearestStopDistanceMeters,
            )
        }

        if (destinationStop == null || !ride.hasBoarded) {
            val waitingStop = boardingStop ?: nearestStop
            if (waitingStop == null) {
                return TrackingSnapshot(
                    title = session.routeName,
                    content = "等待目前位置...",
                    subText = session.pathName.ifBlank { "背景乘車提醒進行中" },
                    progressMax = null,
                    progressValue = null,
                    shortCriticalText = "定位中",
                )
            }
            val boardingPointCount = boardingIndex.takeIf { it >= 0 }?.plus(1) ?: 1
            val busPoint = ride.nextBusVehicleId
                ?.let { tracked ->
                    findTrackedBusIndex(
                        stops = session.stops,
                        liveStops = liveStops,
                        preferredVehicleId = tracked,
                    )
                }
                ?.plus(1)
                ?.coerceAtMost(boardingPointCount)
                ?: 0
            return TrackingSnapshot(
                title = if (destinationStop == null) {
                    session.routeName
                } else {
                    "${session.routeName} · ${waitingStop.stopName}"
                },
                content = if (destinationStop == null) {
                    "${waitingStop.stopName} 約 ${displayEtaText(liveStops[waitingStop.stopId])}"
                } else {
                    "公車到 ${waitingStop.stopName} 約 $boardingEtaText"
                },
                subText = if (destinationStop == null) {
                    buildNearestStatusText(
                        session = session,
                        nearestStop = waitingStop,
                        nearestEtaText = displayEtaText(liveStops[waitingStop.stopId]),
                        busStopsAway = busStopsUntilBoarding,
                    )
                } else {
                    buildWaitingBoardingText(
                        session = session,
                        boardingStop = waitingStop,
                        destinationStop = destinationStop,
                        busStopsUntilBoarding = busStopsUntilBoarding,
                    )
                },
                progressMax = toProgressMax(boardingPointCount),
                progressValue = toProgressValue(busPoint, boardingPointCount),
                shortCriticalText = buildShortCriticalText(
                    busStopsUntilBoarding,
                    if (destinationStop == null) {
                        displayShortEtaText(liveStops[waitingStop.stopId])
                    } else {
                        boardingEtaShort
                    },
                ),
                hasBoarded = false,
                boardingName = waitingStop.stopName,
                boardingEtaText = boardingEtaText,
                boardingEtaSeconds = boardingEtaSeconds,
                boardingStopsAway = busStopsUntilBoarding,
                boardingDistanceMeters = ride.boardingStopDistanceMeters,
                boardingVehicleId = boardingVehicleId,
                boardingVehiclePassedStop = false,
                boardingPromptEligible = ride.boardingPromptDue,
                destinationName = destinationStop?.stopName,
                nearestStopDistanceMeters = nearestStopDistanceMeters,
            )
        }

        // On board: progress comes from the user's own position, falling back to
        // the vehicle they are riding when the phone stops reporting.
        val travelIndex = ride.progressStopIndex.takeIf { it >= 0 }
            ?: ride.nearestStopIndexOnBoard(liveStops, session.stops)
            ?: nearestIndex
        val journeyStartIndex = boardingIndex.coerceAtLeast(0).coerceAtMost(destinationIndex)
        val journeyPointCount = (destinationIndex - journeyStartIndex + 1).coerceAtLeast(1)
        val currentProgressPoint = if (travelIndex >= 0) {
            (travelIndex.coerceAtLeast(journeyStartIndex) - journeyStartIndex) + 1
        } else {
            1
        }.coerceIn(1, journeyPointCount)
        val destinationLive = liveStops[destinationStop.stopId]
        val destinationEtaText = displayEtaText(
            destinationLive,
            ride.trackedVehicleId,
            fallbackToAnyVehicle = ride.trackedVehicleId == null,
        )
        val destinationEtaShort = displayShortEtaText(
            destinationLive,
            ride.trackedVehicleId,
            fallbackToAnyVehicle = ride.trackedVehicleId == null,
        )
        val remainingStops = ride.remainingStops ?: (destinationIndex - journeyStartIndex)
            .coerceAtLeast(0)

        return TrackingSnapshot(
            title = "${session.routeName} · ${destinationStop.stopName}",
            content = when {
                remainingStops == 0 -> "已接近 ${destinationStop.stopName}"
                else -> "距離 ${destinationStop.stopName} 還有 $remainingStops 站 · $destinationEtaText"
            },
            subText = buildOnboardTripSubText(
                nearestStop?.stopName ?: destinationStop.stopName,
            ),
            progressMax = toProgressMax(journeyPointCount),
            progressValue = toProgressValue(currentProgressPoint, journeyPointCount),
            shortCriticalText = buildShortCriticalText(remainingStops, destinationEtaShort),
            hasBoarded = true,
            destinationName = destinationStop.stopName,
            remainingStops = remainingStops,
            destinationDistanceMeters = ride.destinationDistanceMeters,
            boardingName = boardingStop?.stopName,
            boardingVehicleId = ride.trackedVehicleId ?: boardingVehicleId,
            passedDestinationByStops = ride.passedDestinationByStops,
            nearestStopDistanceMeters = nearestStopDistanceMeters,
            hasRouteValidProgress = ride.hasRouteValidProgress,
        )
    }

    /**
     * Last resort for on-board progress when the user's own fixes are gone: the
     * stop the tracked vehicle has reached, found through the live feed.
     */
    private fun RideSnapshot.nearestStopIndexOnBoard(
        liveStops: Map<Int, LiveStopState>,
        stops: List<TrackingStop>,
    ): Int? {
        val vehicleId = trackedVehicleId ?: return null
        return findTrackedBusIndex(
            stops = stops,
            liveStops = liveStops,
            preferredVehicleId = vehicleId,
        )
    }

    private fun findNearestStopIndex(
        stops: List<TrackingStop>,
        location: Location,
    ): Int {
        return stops.indices.minByOrNull { index ->
            val stop = stops[index]
            distanceMeters(
                location.latitude,
                location.longitude,
                stop.lat,
                stop.lon,
            )
        } ?: -1
    }

    private fun buildNearestStatusText(
        session: TrackingSession,
        nearestStop: TrackingStop,
        nearestEtaText: String,
        busStopsAway: Int?,
    ): String {
        val parts = mutableListOf<String>()
        if (session.pathName.isNotBlank()) {
            parts += session.pathName
        }
        parts += "最近站牌 ${nearestStop.stopName}"
        if (nearestEtaText != "--") {
            parts += nearestEtaText
        }
        buildBusDistanceSummary(busStopsAway)?.let(parts::add)
        return parts.joinToString(" · ")
    }

    private fun buildWaitingBoardingText(
        session: TrackingSession,
        boardingStop: TrackingStop,
        destinationStop: TrackingStop,
        busStopsUntilBoarding: Int?,
    ): String {
        val parts = mutableListOf<String>()
        if (session.pathName.isNotBlank()) {
            parts += session.pathName
        }
        parts += "尚未上車"
        parts += "上車站 ${boardingStop.stopName}"
        parts += "目的地 ${destinationStop.stopName}"
        buildBusDistanceSummary(busStopsUntilBoarding)?.let(parts::add)
        return parts.joinToString(" · ")
    }

    private fun buildBusDistanceSummary(stopsAway: Int?): String? {
        return when (stopsAway) {
            null -> null
            0 -> "公車即將進站"
            else -> "公車還有 $stopsAway 站"
        }
    }

    private fun displayEtaText(
        liveStopState: LiveStopState?,
        preferredVehicleId: String? = null,
        fallbackToAnyVehicle: Boolean = true,
    ): String {
        val selectedEta = findEtaForVehicle(liveStopState, preferredVehicleId)
        return composeEtaText(
            seconds = selectedEta?.seconds ?: if (fallbackToAnyVehicle) liveStopState?.seconds else null,
            message = selectedEta?.message ?: if (fallbackToAnyVehicle) liveStopState?.message else null,
        )
    }

    private fun displayShortEtaText(
        liveStopState: LiveStopState?,
        preferredVehicleId: String? = null,
        fallbackToAnyVehicle: Boolean = true,
    ): String {
        val selectedEta = findEtaForVehicle(liveStopState, preferredVehicleId)
        return composeShortEtaText(
            seconds = selectedEta?.seconds ?: if (fallbackToAnyVehicle) liveStopState?.seconds else null,
            message = selectedEta?.message ?: if (fallbackToAnyVehicle) liveStopState?.message else null,
        )
    }

    private fun findEtaForVehicle(
        stopState: LiveStopState?,
        preferredVehicleId: String?,
    ): LiveEtaEntry? {
        val normalizedVehicleId = normalizeVehicleId(preferredVehicleId) ?: return null
        return stopState?.etaEntries?.firstOrNull { etaEntry ->
            normalizeVehicleId(etaEntry.vehicleId) == normalizedVehicleId
        }
    }

    private fun normalizeVehicleId(vehicleId: String?): String? {
        val cleaned = vehicleId
            ?.trim()
            ?.replace(" ", "")
            .orEmpty()
        if (cleaned.isEmpty()) {
            return null
        }
        return cleaned.uppercase()
    }

    private fun resolveEtaSeconds(
        stopState: LiveStopState?,
        preferredVehicleId: String? = null,
    ): Int? {
        val selectedEta = findEtaForVehicle(stopState, preferredVehicleId)
        return selectedEta?.seconds ?: stopState?.seconds
    }

    private fun composeEtaText(seconds: Int?, message: String?): String {
        val trimmedMessage = message?.trim().orEmpty()
        if (trimmedMessage.isNotEmpty()) {
            return when {
                trimmedMessage.contains("進站") || trimmedMessage.contains("到站") -> "進站中"
                trimmedMessage.contains("即將") -> "即將進站"
                trimmedMessage.contains("未發車") -> "未發車"
                trimmedMessage.contains("末班") -> "末班已過"
                else -> trimmedMessage
            }
        }

        val etaSeconds = seconds ?: return "--"
        if (etaSeconds <= 0) {
            return "進站中"
        }
        if (etaSeconds < 60) {
            return "即將進站"
        }
        return "${etaSeconds / 60} 分"
    }

    private fun composeShortEtaText(seconds: Int?, message: String?): String {
        val trimmedMessage = message?.trim().orEmpty()
        if (trimmedMessage.isNotEmpty()) {
            return when {
                trimmedMessage.contains("進站") || trimmedMessage.contains("到站") -> "進站"
                trimmedMessage.contains("即將") -> "即將"
                trimmedMessage.contains("未發車") -> "未發"
                trimmedMessage.contains("末班") -> "末班"
                else -> trimmedMessage.take(6)
            }
        }

        val etaSeconds = seconds ?: return "--"
        if (etaSeconds <= 0) {
            return "進站"
        }
        if (etaSeconds < 60) {
            return "<1分"
        }
        return "${etaSeconds / 60}分"
    }

    private fun isImmediateEtaText(etaText: String?): Boolean {
        val value = etaText?.trim().orEmpty()
        return value.contains("進站") || value.contains("即將")
    }

    /**
     * The button that lets the user answer the boarding question by hand. It is
     * offered while waiting for the bus as well, so detection is never the only
     * way to start a trip.
     */
    private fun TrackingSnapshot.boardingActions(): String? {
        return when {
            hasBoarded -> null
            boardingName != null -> "我已上車"
            else -> null
        }
    }

    /** The counterpart button, offered once a ride is being tracked. */
    private fun TrackingSnapshot.notBoardedAction(): String? {
        return if (hasBoarded) "還沒上車" else null
    }

    private fun buildTrackingNotification(snapshot: TrackingSnapshot): Notification {
        val currentSession = session ?: return buildStoppedNotification()
        return if (supportsFrameworkLiveUpdate()) {
            buildFrameworkTrackingNotification(currentSession, snapshot)
        } else {
            buildCompatTrackingNotification(currentSession, snapshot)
        }
    }

    private fun applyShortCriticalPresentation(
        builder: NotificationCompat.Builder,
        shortCriticalText: String?,
    ) {
        val trimmed = shortCriticalText?.trim().orEmpty()
        val countdownWhen = parseShortCriticalCountdownWhen(trimmed)
        if (countdownWhen != null) {
            builder
                .setShowWhen(true)
                .setWhen(countdownWhen)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
            return
        }
        builder
            .setShowWhen(false)
            .setUsesChronometer(false)
        trimmed.takeIf { it.isNotEmpty() }?.let(builder::setShortCriticalText)
    }

    private fun applyShortCriticalPresentation(
        builder: Notification.Builder,
        shortCriticalText: String?,
    ) {
        val trimmed = shortCriticalText?.trim().orEmpty()
        val countdownWhen = parseShortCriticalCountdownWhen(trimmed)
        if (countdownWhen != null) {
            builder
                .setShowWhen(true)
                .setWhen(countdownWhen)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
            return
        }
        builder
            .setShowWhen(false)
            .setUsesChronometer(false)
        trimmed.takeIf { it.isNotEmpty() }?.let(builder::setShortCriticalText)
    }

    private fun parseShortCriticalCountdownWhen(shortCriticalText: String): Long? {
        val match = SHORT_CRITICAL_COUNTDOWN_REGEX.matchEntire(shortCriticalText) ?: return null
        val minutes = match.groupValues[1].toLongOrNull() ?: return null
        val seconds = match.groupValues[2].toLongOrNull() ?: return null
        val totalMillis = (minutes * 60L + seconds) * 1_000L
        return System.currentTimeMillis() + totalMillis
    }


    private fun buildProgressPointPositions(progressMax: Int): List<Int> {
        if (progressMax <= 0) {
            return emptyList()
        }
        val pointOffset = (PROGRESS_POINT_UNIT / 2).coerceAtLeast(1)
        val lastPointPosition = (progressMax - pointOffset).coerceAtLeast(pointOffset)
        return generateSequence(pointOffset) { current ->
            (current + PROGRESS_POINT_UNIT).takeIf { it <= lastPointPosition }
        }.toList()
    }

    private fun toProgressMax(pointCount: Int): Int {
        return pointCount.coerceAtLeast(1) * PROGRESS_POINT_UNIT
    }

    private fun toProgressValue(pointIndex: Int, pointCount: Int): Int {
        return pointIndex.coerceIn(0, pointCount.coerceAtLeast(1)) * PROGRESS_POINT_UNIT
    }

    private fun buildStoppedNotification(): Notification {
        return NotificationCompat.Builder(this, TRACKING_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_status_bus)
            .setContentTitle("YABus")
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun buildCompatTrackingNotification(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ): Notification {
        val openRouteIntent = createOpenRoutePendingIntent(session)
        val stopIntent = createStopPendingIntent()
        val markBoardedIntent = createMarkBoardedPendingIntent()
        val notBoardedIntent = createNotBoardedPendingIntent()
        val builder = NotificationCompat.Builder(this, TRACKING_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_status_bus)
            .setContentTitle(snapshot.title)
            .setContentText(snapshot.content)
            .setSubText(snapshot.subText)
            .setContentIntent(openRouteIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPublicVersion(buildPublicTrackingNotification(session, snapshot))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(
                NotificationCompat.Action.Builder(
                    0,
                    "停止",
                    stopIntent,
                ).build(),
            )

        snapshot.boardingActions()?.let { action ->
            builder.addAction(
                NotificationCompat.Action.Builder(0, action, markBoardedIntent).build(),
            )
        }
        snapshot.notBoardedAction()?.let { action ->
            builder.addAction(
                NotificationCompat.Action.Builder(0, action, notBoardedIntent).build(),
            )
        }

        applyShortCriticalPresentation(builder, snapshot.shortCriticalText)

        requestPromotedOngoing(builder)
        val progressMax = snapshot.progressMax
        val progressValue = snapshot.progressValue
        if (progressMax != null && progressValue != null && progressMax > 0) {
            val clampedValue = progressValue.coerceIn(0, progressMax)
            val progressPoints = buildProgressPointPositions(progressMax)
            builder.setProgress(progressMax, clampedValue, false)
            val progressStyle = NotificationCompat.ProgressStyle()
                .setStyledByProgress(true)
                .setProgress(clampedValue)
                .setProgressTrackerIcon(
                    IconCompat.createWithResource(this, R.drawable.ic_progress_bus),
                )
                .setProgressSegments(
                    mutableListOf(
                        NotificationCompat.ProgressStyle.Segment(progressMax),
                    ),
                )
                .setProgressPoints(
                    progressPoints.mapTo(mutableListOf()) { position ->
                        NotificationCompat.ProgressStyle.Point(position)
                            .setColor(PROGRESS_POINT_COLOR)
                    },
                )
                .setProgressEndIcon(
                    IconCompat.createWithResource(this, R.drawable.ic_progress_flag),
                )
            builder.setStyle(progressStyle)
        } else {
            builder.setProgress(0, 0, false)
        }

        val notification = builder.build()
        return TripMonitorEnhancedSurfaceSupport.apply(
            context = this,
            notification = notification,
            session = session,
            snapshot = snapshot,
            contentIntent = openRouteIntent,
            stopIntent = stopIntent,
            markBoardedIntent = markBoardedIntent,
            notBoardedIntent = notBoardedIntent,
        )
    }

    private fun buildFrameworkTrackingNotification(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ): Notification {
        val openRouteIntent = createOpenRoutePendingIntent(session)
        val stopIntent = createStopPendingIntent()
        val markBoardedIntent = createMarkBoardedPendingIntent()
        val notBoardedIntent = createNotBoardedPendingIntent()
        val builder = Notification.Builder(this, TRACKING_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_status_bus)
            .setContentTitle(snapshot.title)
            .setContentText(snapshot.content)
            .setSubText(snapshot.subText)
            .setContentIntent(openRouteIntent)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPublicVersion(buildPublicTrackingNotification(session, snapshot))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_NAVIGATION)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "停止",
                    stopIntent,
                ).build(),
            )

        snapshot.boardingActions()?.let { action ->
            builder.addAction(Notification.Action.Builder(null, action, markBoardedIntent).build())
        }
        snapshot.notBoardedAction()?.let { action ->
            builder.addAction(Notification.Action.Builder(null, action, notBoardedIntent).build())
        }

        applyShortCriticalPresentation(builder, snapshot.shortCriticalText)

        requestPromotedOngoing(builder)
        val progressMax = snapshot.progressMax
        val progressValue = snapshot.progressValue
        if (progressMax != null && progressValue != null && progressMax > 0) {
            val clampedValue = progressValue.coerceIn(0, progressMax)
            val progressPoints = buildProgressPointPositions(progressMax)
            builder.setProgress(progressMax, clampedValue, false)
            val progressStyle = Notification.ProgressStyle()
                .setStyledByProgress(true)
                .setProgress(clampedValue)
                .setProgressTrackerIcon(
                    Icon.createWithResource(this, R.drawable.ic_progress_bus),
                )
                .setProgressSegments(
                    mutableListOf(
                        Notification.ProgressStyle.Segment(progressMax),
                    ),
                )
                .setProgressPoints(
                    progressPoints.mapTo(mutableListOf()) { position ->
                        Notification.ProgressStyle.Point(position)
                            .setColor(PROGRESS_POINT_COLOR)
                    },
                )
                .setProgressEndIcon(
                    Icon.createWithResource(this, R.drawable.ic_progress_flag),
                )
            builder.setStyle(progressStyle)
        }

        val notification = builder.build()
        return TripMonitorEnhancedSurfaceSupport.apply(
            context = this,
            notification = notification,
            session = session,
            snapshot = snapshot,
            contentIntent = openRouteIntent,
            stopIntent = stopIntent,
            markBoardedIntent = markBoardedIntent,
            notBoardedIntent = notBoardedIntent,
        )
    }

    private fun buildPublicTrackingNotification(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ): Notification {
        val notification = NotificationCompat.Builder(this, TRACKING_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_status_bus)
            .setContentTitle(snapshot.title)
            .setContentText(snapshot.content)
            .setSubText(snapshot.subText)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        return TripMonitorEnhancedSurfaceSupport.apply(
            context = this,
            notification = notification,
            session = session,
            snapshot = snapshot,
            contentIntent = createOpenRoutePendingIntent(session),
            stopIntent = createStopPendingIntent(),
            includeHyperIsland = false,
        )
    }

    private fun maybeSendTripAlerts(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ) {
        if (snapshot.passedDestinationByStops != null) {
            // Fixes can skip the destination entirely. Passing it is also an
            // arrival baseline, without restarting a countdown already running.
            if (arrivalDetectedAtMs == 0L) {
                arrivalDetectedAtMs = System.currentTimeMillis()
            }
            if (maybeSendOvershotAlert(session, snapshot)) {
                return
            }
            maybePauseAfterArrivalGrace()
            return
        }
        if (snapshot.hasBoarded && snapshot.destinationName == null) {
            if (
                lastWentBackgroundAtMs > 0L &&
                System.currentTimeMillis() - lastWentBackgroundAtMs <
                    BACKGROUND_AUTO_PAUSE_GRACE_MS
            ) {
                return
            }
            maybeSendDestinationSetupPrompt(session, snapshot)
            pauseTracking(
                PAUSE_REASON_BOARDED_NO_DESTINATION,
                preserveAlertNotification = true,
            )
            return
        }
        if (!snapshot.hasBoarded) {
            maybeSendBoardingAlert(session, snapshot)
            maybeSendBoardingCheckPrompt(session, snapshot)
            return
        }
        cancelBoardingCheckPrompt()
        maybeSendDestinationAlert(session, snapshot)
        maybePauseAfterArrivalGrace()
    }

    private fun maybeSendBoardingAlert(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ) {
        if (boardingAlertSent) {
            return
        }
        val boardingName = snapshot.boardingName ?: return
        val destinationName = snapshot.destinationName ?: return
        val busStopsAway = snapshot.boardingStopsAway
        val shouldAlert = (busStopsAway != null && busStopsAway <= 1) ||
            isImmediateEtaText(snapshot.boardingEtaText)
        if (!shouldAlert) {
            return
        }

        boardingAlertSent = true
        notificationManager.notify(
            ALERT_NOTIFICATION_ID,
            NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_status_bus)
                .setContentTitle("準備上車")
                .setContentText("$boardingName 的公車快到了")
                .setSubText(session.pathName)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPublicVersion(
                    NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                        .setSmallIcon(R.drawable.ic_status_bus)
                        .setContentTitle("準備上車")
                        .setContentText("$boardingName 的公車快到了")
                        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                        .build(),
                )
                .setStyle(
                    NotificationCompat.BigTextStyle().bigText(
                        "$boardingName 的公車快到了，請準備上車。上車後會繼續提醒你前往 $destinationName。",
                    ),
                )
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(createOpenRoutePendingIntent(session))
                .build(),
        )
    }

    private fun maybeSendBoardingCheckPrompt(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ) {
        val ride = currentRideSnapshot()
        if (!ride.boardingPromptDue || ride.boardingCheckId == 0L) {
            // The question was answered, retired or overtaken by a detection.
            if (snapshot.hasBoarded || ride.boardingCheckId == 0L) {
                cancelBoardingCheckPrompt()
            }
            return
        }
        if (boardingCheckNotificationId == ride.boardingCheckId) {
            return
        }
        val boardingName = snapshot.boardingName ?: return

        boardingCheckNotificationId = ride.boardingCheckId
        notificationManager.notify(
            BOARDING_CHECK_NOTIFICATION_ID,
            NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_status_bus)
                .setContentTitle("你有上車嗎？")
                .setContentText("$boardingName 的公車剛剛離站了。")
                .setSubText(session.pathName)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(createOpenRoutePendingIntent(session))
                .addAction(
                    NotificationCompat.Action.Builder(
                        0,
                        "我已上車",
                        createMarkBoardedPendingIntent(),
                    ).build(),
                )
                .addAction(
                    NotificationCompat.Action.Builder(
                        0,
                        "還沒上車",
                        createNotBoardedPendingIntent(),
                    ).build(),
                )
                .build(),
        )
    }

    private fun cancelBoardingCheckPrompt() {
        boardingCheckNotificationId = 0L
        notificationManager.cancel(BOARDING_CHECK_NOTIFICATION_ID)
    }

    private fun maybeSendDestinationSetupPrompt(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ) {
        if (destinationSetupPromptSent) {
            return
        }
        destinationSetupPromptSent = true
        val boardingName = snapshot.boardingName
        val contentText = if (boardingName.isNullOrBlank()) {
            "已偵測到可能上車，要設定下車站嗎？"
        } else {
            "已偵測在 $boardingName 上車，要設定下車站嗎？"
        }
        notificationManager.notify(
            ALERT_NOTIFICATION_ID,
            NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_status_bus)
                .setContentTitle("已偵測上車")
                .setContentText(contentText)
                .setSubText(session.pathName)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(createOpenRoutePendingIntent(session))
                .build(),
        )
    }

    /**
     * Two heads-up alerts. "Stops remaining" counts the destination itself, so
     * one remaining means the next stop is the user's — that, rather than a
     * fixed distance, is what should prompt them to get ready, because a
     * long segment can easily run past a couple of hundred metres.
     */
    private fun maybeSendDestinationAlert(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ) {
        val destinationName = snapshot.destinationName ?: return
        val remainingStops = snapshot.remainingStops ?: return
        val distanceMeters = snapshot.destinationDistanceMeters ?: return
        val now = System.currentTimeMillis()
        val nextStopIsDestination = remainingStops <= 1

        if (remainingStops <= 2 && destinationAlertStage < 1) {
            destinationAlertStage = 1
            notificationManager.notify(
                ALERT_NOTIFICATION_ID,
                NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_status_bus)
                    .setContentTitle("${session.routeName} 快到了")
                    .setContentText("$destinationName 還有 $remainingStops 站")
                    .setSubText(session.pathName)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setPublicVersion(
                        NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                            .setSmallIcon(R.drawable.ic_status_bus)
                            .setContentTitle("${session.routeName} 快到了")
                            .setContentText("$destinationName 還有 $remainingStops 站")
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                            .build(),
                    )
                    .setStyle(
                        NotificationCompat.BigTextStyle().bigText(
                            "$destinationName 大約還有 $remainingStops 站，請留意站序，準備下車。",
                        ),
                    )
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
                    .setAutoCancel(true)
                    .setContentIntent(createOpenRoutePendingIntent(session))
                    .build(),
            )
        }

        if ((nextStopIsDestination || distanceMeters <= DESTINATION_ARRIVED_DISTANCE_METERS) &&
            destinationAlertStage < 2
        ) {
            destinationAlertStage = 2
            notificationManager.notify(
                ALERT_NOTIFICATION_ID,
                NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_status_bus)
                    .setContentTitle("準備下車")
                    .setContentText("你已接近 $destinationName")
                    .setSubText(session.pathName)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setPublicVersion(
                        NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                            .setSmallIcon(R.drawable.ic_status_bus)
                            .setContentTitle("準備下車")
                            .setContentText("你已接近 $destinationName")
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                            .build(),
                    )
                    .setStyle(
                        NotificationCompat.BigTextStyle().bigText(
                            "你已接近 $destinationName，請準備下車。",
                        ),
                    )
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setAutoCancel(true)
                    .setContentIntent(createOpenRoutePendingIntent(session))
                    .build(),
            )
        }

        // Arrival — not "the next stop is yours" — is what starts the countdown
        // to the auto-pause and the overshoot check.
        if (arrivalDetectedAtMs == 0L &&
            (remainingStops == 0 || distanceMeters <= DESTINATION_ARRIVED_DISTANCE_METERS)
        ) {
            arrivalDetectedAtMs = now
        }
    }

    private fun maybeSendOvershotAlert(
        session: TrackingSession,
        snapshot: TrackingSnapshot,
    ): Boolean {
        if (overshootAlertSent) {
            return true
        }
        if (arrivalDetectedAtMs == 0L) {
            return false
        }
        if (System.currentTimeMillis() - arrivalDetectedAtMs < OVERSHOOT_CONFIRM_DELAY_MS) {
            return false
        }
        val destinationName = snapshot.destinationName ?: return false
        val passedByStops = snapshot.passedDestinationByStops ?: return false
        val destinationDistanceMeters = snapshot.destinationDistanceMeters ?: return false
        if (
            destinationDistanceMeters <= DESTINATION_OVERSHOOT_DISTANCE_METERS ||
                !snapshot.hasRouteValidProgress
        ) {
            return false
        }

        overshootAlertSent = true
        notificationManager.notify(
            ALERT_NOTIFICATION_ID,
            NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_status_bus)
                .setContentTitle("可能坐過站了")
                .setContentText("你已超過 $destinationName ${passedByStops} 站")
                .setSubText(session.pathName)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(createOpenRoutePendingIntent(session))
                .build(),
        )
        pauseTracking(
            PAUSE_REASON_OVERSHOT,
            preserveAlertNotification = true,
        )
        return true
    }

    private fun maybePauseAfterArrivalGrace() {
        if (arrivalDetectedAtMs == 0L || overshootAlertSent) {
            return
        }
        if (System.currentTimeMillis() - arrivalDetectedAtMs < ARRIVAL_AUTO_PAUSE_DELAY_MS) {
            return
        }
        pauseTracking(
            PAUSE_REASON_ARRIVED,
            preserveAlertNotification = true,
        )
    }

    private fun createTrackingNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                TRACKING_CHANNEL_ID,
                "背景乘車提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "在背景持續追蹤目前路線與下車提醒。"
            },
        )
    }

    private fun createAlertNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel(LEGACY_TRACKING_CHANNEL_ID)
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "下車提醒",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "接近目的地時提醒你準備下車。"
                enableLights(true)
                lightColor = Color.CYAN
                enableVibration(true)
            },
        )
    }

    private fun createOpenRoutePendingIntent(session: TrackingSession): PendingIntent {
        val intent = AppLaunchConstants.createRouteDetailIntent(
            context = this,
            provider = session.provider,
            routeKey = session.routeKey,
            pathId = session.pathId,
            // The full-width id, because Dart compares it against the ids its
            // own stop models carry: a folded 高雄 id matches nothing there, so
            // tapping the notification would not select the stop.
            stopId = session.destinationLaunchStopId
                ?: session.stops.firstOrNull()?.launchStopId?.takeIf { it > 0L },
        )
        return PendingIntent.getActivity(
            this,
            session.routeKey * 101 + session.pathId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createStopPendingIntent(): PendingIntent {
        val intent = Intent(this, RouteTripMonitorService::class.java).apply {
            action = ACTION_PAUSE
        }
        return PendingIntent.getService(
            this,
            404,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createMarkBoardedPendingIntent(): PendingIntent {
        val intent = Intent(this, RouteTripMonitorService::class.java).apply {
            action = ACTION_MARK_BOARDED
        }
        return PendingIntent.getService(
            this,
            405,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotBoardedPendingIntent(): PendingIntent {
        val intent = Intent(this, RouteTripMonitorService::class.java).apply {
            action = ACTION_NOT_BOARDED
        }
        return PendingIntent.getService(
            this,
            406,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        AppRuntimeStateStore.setAppInForeground(this, false)
        stopTracking()
        super.onTaskRemoved(rootIntent)
    }

    private fun pauseTracking(
        reason: String,
        explicitSession: TrackingSession? = null,
        preserveAlertNotification: Boolean = false,
    ) {
        val sessionToPause = explicitSession ?: session
        if (sessionToPause != null) {
            AppRuntimeStateStore.savePausedTripMonitor(this, sessionToPause, reason)
        }
        stopTracking(cancelAlertNotification = !preserveAlertNotification)
    }

    private fun stopTracking(cancelAlertNotification: Boolean = true) {
        // Release any pending start obligation before doing cleanup that may
        // involve other processes (location and notification services).
        stopSelf()
        foregroundStarted = false
        latestLocation = null
        boardingAlertSent = false
        destinationSetupPromptSent = false
        arrivalDetectedAtMs = 0L
        destinationAlertStage = 0
        overshootAlertSent = false
        synchronized(detectorLock) {
            session = null
            detector = null
            latestRide = RideSnapshot()
        }
        synchronized(refreshLock) {
            refreshInFlight = false
            refreshPending = false
            lastRefreshStartedAtMs = 0L
        }
        forgetLiveFeeds()
        cancelBoardingCheckPrompt()
        releaseWakeLock()
        mainHandler.removeCallbacksAndMessages(null)
        runCatching {
            if (::fusedLocationClient.isInitialized) {
                fusedLocationClient.removeLocationUpdates(locationCallback)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        notificationManager.cancel(TRACKING_NOTIFICATION_ID)
        if (cancelAlertNotification) {
            notificationManager.cancel(ALERT_NOTIFICATION_ID)
        }
    }

    /** Forgets what was fetched and when, which makes both feeds due at once. */
    private fun forgetLiveFeeds() = synchronized(refreshLock) {
        cachedLiveRouteIds = emptyList()
        cachedLivePathId = null
        cachedLiveFetchedAtMs = 0L
        cachedLiveStops = emptyMap()
        busFeedRefreshByRoute.clear()
        liveStopBackoffUntilMs = 0L
    }

    /**
     * The cached stop feed. Fetching happens in [updateLiveData] so that the
     * snapshot builder never blocks on the network and both feeds are
     * throttled together.
     */
    private fun fetchLiveStopMap(session: TrackingSession): Map<Int, LiveStopState> {
        if (session.realtimeRouteIds.isEmpty()) {
            return emptyMap()
        }
        return synchronized(refreshLock) {
            if (cachedLiveRouteIds == session.realtimeRouteIds && cachedLivePathId == session.pathId) {
                cachedLiveStops
            } else {
                emptyMap()
            }
        }
    }

    /** The live feed for the route and its variants; empty when fetching failed. */
    private fun fetchLiveStopMapFromBackend(
        session: TrackingSession,
    ): Map<Int, LiveStopState> {
        if (session.realtimeRouteIds.isEmpty()) {
            return emptyMap()
        }
        // The family fetch covers the route and its variants; a single-route
        // session is just the one-id case of it.
        return familyRealtime.fetch(session)
    }

    /** Live positions of every vehicle on the route; null when the request failed. */
    private fun fetchBusReportsFromBackend(routeId: String): List<RideBusReport>? {
        val encodedRouteId = URLEncoder.encode(routeId, Charsets.UTF_8.name())
        val array = fetchBackendJsonArray("/api/v1/routes/$encodedRouteId/realtime/buses")
            ?: return null
        val receivedAtMs = System.currentTimeMillis()
        return runCatching { parseBusReports(array, receivedAtMs) }.getOrNull()
    }

    private fun parseBusReports(
        array: JSONArray,
        receivedAtMs: Long,
    ): List<RideBusReport> {
        val reports = ArrayList<RideBusReport>(array.length())
        for (index in 0 until array.length()) {
            val bus = array.optJSONObject(index) ?: continue
            val vehicleId = normalizeVehicleId(bus.opt("id")?.toString())
                ?: normalizeVehicleId(bus.opt("plate")?.toString())
                ?: continue
            val latitude = bus.optDouble("lat", Double.NaN)
            val longitude = bus.optDouble("lon", Double.NaN)
            if (latitude.isNaN() || longitude.isNaN()) {
                continue
            }
            // GPSTime is unix seconds; a missing one makes the report unusable
            // because there is nothing to line the user's track up against.
            val gpsTimeMs = (toIntOrNull(bus.opt("time"))?.toLong() ?: continue) * 1000L
            reports += RideBusReport(
                vehicleId = vehicleId,
                pathId = toIntOrNull(bus.opt("direction")),
                latitude = latitude,
                longitude = longitude,
                gpsTimeMs = gpsTimeMs,
                receivedAtMs = receivedAtMs,
            )
        }
        return reports
    }

    /** Raw body of a backend GET; null when the request failed. Replaced in tests. */
    internal var fetchBackendJsonText: (String) -> String? = ::httpGetBackend

    private fun httpGetBackend(path: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            connection = URL("$BACKEND_BASE_URL$path").openConnection() as HttpURLConnection
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.requestMethod = "GET"
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("User-Agent", NativeApiUserAgent.value())
            connection.doInput = true
            connection.useCaches = false
            if (connection.responseCode !in 200..299) {
                return null
            }
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                reader.readText()
            }
        } catch (_: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    /** A JSON object response, addressed relative to `/api/v1/`. */
    private fun fetchBackendJson(path: String): JSONObject? {
        return fetchBackendJsonText("/api/v1/$path")?.let { text ->
            runCatching { JSONObject(text) }.getOrNull()
        }
    }

    /** A JSON array response; `/realtime/buses` returns one. */
    private fun fetchBackendJsonArray(path: String): JSONArray? {
        return fetchBackendJsonText(path)?.let { text ->
            runCatching { JSONArray(text) }.getOrNull()
        }
    }

    private fun toIntOrNull(raw: Any?): Int? {
        return when (raw) {
            is Number -> raw.toInt()
            else -> raw?.toString()?.trim()?.toIntOrNull()
        }
    }

    private fun buildShortCriticalText(stopsAway: Int?, etaText: String): String? {
        val cleanEtaText = cleanStandaloneShortEtaText(etaText)
        if (stopsAway == null) {
            return cleanEtaText
        }
        if (stopsAway == 0 && cleanEtaText != null) {
            return cleanEtaText
        }

        val left = when (stopsAway) {
            0 -> "到站"
            else -> "${stopsAway}站"
        }
        val compact = when {
            cleanEtaText == null -> left
            else -> "$left|$cleanEtaText"
        }
        return compact.take(7)
    }

    private fun cleanStandaloneShortEtaText(etaText: String): String? {
        val trimmed = etaText.trim()
        if (trimmed.isEmpty() || trimmed == "--") {
            return null
        }
        return trimmed.take(7)
    }

    /** Index of the stop where the live feed last saw [preferredVehicleId]. */
    private fun findTrackedBusIndex(
        stops: List<TrackingStop>,
        liveStops: Map<Int, LiveStopState>,
        preferredVehicleId: String?,
    ): Int? {
        val normalizedVehicleId = normalizeVehicleId(preferredVehicleId) ?: return null
        return stops.indexOfFirst { stop ->
            val stopState = liveStops[stop.stopId]
            stopState != null &&
                (
                    stopState.vehicleIds.any { normalizeVehicleId(it) == normalizedVehicleId } ||
                        stopState.etaEntries.any {
                            normalizeVehicleId(it.vehicleId) == normalizedVehicleId
                        }
                    )
        }.takeIf { it >= 0 }
    }

    private fun distanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double,
    ): Double {
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lon1, lat2, lon2, results)
        return results[0].toDouble()
    }

    private fun requestPromotedOngoing(builder: Notification.Builder) {
        runCatching {
            builder.javaClass.getMethod(
                "setRequestPromotedOngoing",
                Boolean::class.javaPrimitiveType,
            ).invoke(builder, true)
        }
    }

    private fun requestPromotedOngoing(builder: NotificationCompat.Builder) {
        builder.setRequestPromotedOngoing(true)
    }

    private fun supportsFrameworkLiveUpdate(): Boolean {
        return Build.VERSION.SDK_INT >= LIVE_UPDATE_SDK_INT
    }

    companion object {
        private const val ACTION_START_OR_UPDATE =
            "tw.avianjay.taiwanbus.flutter.action.START_OR_UPDATE_TRIP_MONITOR"
        private const val ACTION_SET_APP_FOREGROUND =
            "tw.avianjay.taiwanbus.flutter.action.SET_TRIP_MONITOR_APP_FOREGROUND"
        private const val ACTION_PAUSE =
            "tw.avianjay.taiwanbus.flutter.action.PAUSE_TRIP_MONITOR"
        private const val ACTION_MARK_BOARDED =
            "tw.avianjay.taiwanbus.flutter.action.MARK_BOARDED"
        private const val ACTION_NOT_BOARDED =
            "tw.avianjay.taiwanbus.flutter.action.NOT_BOARDED"
        private const val ACTION_RESUME =
            "tw.avianjay.taiwanbus.flutter.action.RESUME_TRIP_MONITOR"
        private const val ACTION_STOP =
            "tw.avianjay.taiwanbus.flutter.action.STOP_TRIP_MONITOR"

        private const val EXTRA_SESSION_JSON = "session_json"
        private const val EXTRA_APP_IN_FOREGROUND = "app_in_foreground"
        private const val EXTRA_PAUSE_REASON = "pause_reason"

        private const val LEGACY_TRACKING_CHANNEL_ID = "trip_monitor_tracking"
        private const val TRACKING_CHANNEL_ID = "trip_monitor_tracking_v2"
        private const val ALERT_CHANNEL_ID = "trip_monitor_alerts"
        private const val TRACKING_NOTIFICATION_ID = 6021
        private const val ALERT_NOTIFICATION_ID = 6022
        private const val BOARDING_CHECK_NOTIFICATION_ID = 6023

        private const val BACKEND_BASE_URL = "https://bus.avianjay.sbs"
        private const val POLL_INTERVAL_MS = 15_000L
        private const val LIVE_STOP_REFRESH_INTERVAL_MS = 20_000L
        private const val LIVE_BUS_REFRESH_INTERVAL_MS = 15_000L
        private const val LIVE_FETCH_BACKOFF_MS = 60_000L
        private const val MIN_REFRESH_INTERVAL_MS = 2_000L
        private const val LOCATION_UPDATE_INTERVAL_MS = 12_000L
        private const val LOCATION_MIN_UPDATE_INTERVAL_MS = 6_000L
        private const val BACKGROUND_AUTO_PAUSE_GRACE_MS = 90_000L

        /**
         * How long after pausing for a destination the same ride may still be
         * picked up. A city ride is rarely longer; past this the rider is
         * re-detected from their movement like anyone else.
         */
        private const val BOARDED_RIDE_RESUME_WINDOW_MS = 60 * 60 * 1000L
        private const val WAKE_LOCK_TAG = "YABus::TripMonitor"
        // The lock is renewed on every start, so this only bounds a session that
        // was never cleaned up; it is not the expected trip length.
        private const val WAKE_LOCK_TIMEOUT_MS = 6 * 60 * 60 * 1000L
        private const val PROGRESS_POINT_UNIT = 100
        private const val PROGRESS_POINT_COLOR = 0x80000000.toInt()
        private const val OVERSHOOT_CONFIRM_DELAY_MS = 45_000L
        private const val ARRIVAL_AUTO_PAUSE_DELAY_MS = 60_000L
        private const val DESTINATION_OVERSHOOT_DISTANCE_METERS = 100.0
        private const val DESTINATION_ARRIVED_DISTANCE_METERS = 120.0
        private const val LIVE_UPDATE_SDK_INT = 36
        private const val PAUSE_REASON_USER = "user"
        private const val PAUSE_REASON_ARRIVED = "arrived"
        private const val PAUSE_REASON_OVERSHOT = "overshot"
        private const val PAUSE_REASON_BOARDED_NO_DESTINATION = "boarded_no_destination"
        // Bare values like 13:45 are often scheduled clock times from ETA messages,
        // so only explicitly wrapped strings should render as a countdown chronometer.
        private val SHORT_CRITICAL_COUNTDOWN_REGEX = Regex("^\\(([0-9]{2}):([0-9]{2})\\)$")

        private fun parseSessionJson(sessionJson: String): TrackingSession? {
            return try {
                val root = JSONObject(sessionJson)
                val stopsJson = root.optJSONArray("stops") ?: JSONArray()
                val stops = mutableListOf<TrackingStop>()
                for (index in 0 until stopsJson.length()) {
                    val stop = stopsJson.optJSONObject(index) ?: continue
                    // The id as Dart holds it, which is 64-bit for 高雄. It is
                    // needed twice, as two different numbers: folded, to key
                    // the live feeds; and at full width, for anything a
                    // notification tap carries back into Flutter.
                    val dartStopId = stop.opt("stopId")
                    stops += TrackingStop(
                        // Must match how the live feed folds the same id, or the
                        // two maps never line up for 64-bit ids (高雄).
                        stopId = foldStopId(dartStopId),
                        launchStopId = launchStopId(dartStopId),
                        rawStopId = stop.optString("rawStopId", "")
                            .trim().takeIf { it.isNotEmpty() && it != "null" },
                        stopName = stop.optString("stopName", ""),
                        sequence = stop.optInt("sequence", index),
                        lat = stop.optDouble("lat", 0.0),
                        lon = stop.optDouble("lon", 0.0),
                        liveData = stop.optJSONObject("liveData")?.let(::parseTripMonitorLiveStop),
                    )
                }
                if (stops.isEmpty()) {
                    return null
                }
                TrackingSession(
                    provider = root.optString("provider", "twn"),
                    routeKey = root.optInt("routeKey", 0),
                    routeId = root.optString("routeId", "")
                        .trim()
                        .takeIf { it.isNotEmpty() },
                    routeName = root.optString("routeName", "YABus"),
                    familyRouteIds = root.optJSONArray("familyRouteIds")?.let { ids ->
                        (0 until ids.length()).mapNotNull { index ->
                            ids.optString(index).trim().takeIf { it.isNotEmpty() && it != "null" }
                        }.distinct()
                    }.orEmpty(),
                    pathId = root.optInt("pathId", 0),
                    pathName = root.optString("pathName", ""),
                    appInForeground = root.optBoolean("appInForeground", true),
                    backgroundLocationAlwaysGranted =
                        root.optBoolean("backgroundLocationAlwaysGranted", true),
                    initialLatitude = root.optDouble("initialLatitude", Double.NaN)
                        .takeUnless { it.isNaN() },
                    initialLongitude = root.optDouble("initialLongitude", Double.NaN)
                        .takeUnless { it.isNaN() },
                    initialLocationTimestampMs = root.optLong("initialLocationTimestampMs", 0L)
                        .takeIf { it > 0L },
                    boardingStopId = foldStopId(root.opt("boardingStopId"))
                        .takeIf { it > 0 },
                    boardingStopName = root.optString("boardingStopName", "")
                        .takeIf { it.isNotBlank() },
                    destinationStopId = foldStopId(root.opt("destinationStopId"))
                        .takeIf { it > 0 },
                    destinationStopName = root.optString("destinationStopName", "")
                        .takeIf { it.isNotBlank() },
                    boardingLaunchStopId = launchStopId(root.opt("boardingStopId"))
                        .takeIf { it > 0L },
                    destinationLaunchStopId = launchStopId(root.opt("destinationStopId"))
                        .takeIf { it > 0L },
                    stops = stops.sortedBy { stop -> stop.sequence },
                )
            } catch (_: Exception) {
                null
            }
        }

        fun parseSessionPayload(session: Map<String, Any?>): TrackingSession? {
            return try {
                parseSessionJson(JSONObject(session).toString())
            } catch (_: Exception) {
                null
            }
        }

        fun startOrUpdate(context: Context, session: Map<String, Any?>) {
            val sessionJson = JSONObject(session).toString()
            val intent = Intent(context, RouteTripMonitorService::class.java).apply {
                action = ACTION_START_OR_UPDATE
                putExtra(EXTRA_SESSION_JSON, sessionJson)
            }
            // App-state transitions race with these calls; when the app is no
            // longer eligible (background on Android 12+), fail quietly instead
            // of crashing the process.
            runCatching {
                ContextCompat.startForegroundService(context, intent)
            }
        }

        fun setAppInForeground(context: Context, appInForeground: Boolean) {
            val intent = Intent(context, RouteTripMonitorService::class.java).apply {
                action = ACTION_SET_APP_FOREGROUND
                putExtra(EXTRA_APP_IN_FOREGROUND, appInForeground)
            }
            runCatching {
                context.startService(intent)
            }
        }

        fun pause(context: Context, session: Map<String, Any?>?, reason: String) {
            val intent = Intent(context, RouteTripMonitorService::class.java).apply {
                action = ACTION_PAUSE
                putExtra(EXTRA_PAUSE_REASON, reason)
                session?.let { putExtra(EXTRA_SESSION_JSON, JSONObject(it).toString()) }
            }
            runCatching {
                context.startService(intent)
            }
        }

        fun resume(context: Context) {
            val intent = Intent(context, RouteTripMonitorService::class.java).apply {
                action = ACTION_RESUME
            }
            if (runCatching { context.startService(intent) }.isFailure) {
                // The paused flag must be lifted even when the service cannot
                // be reached (e.g. app momentarily backgrounded).
                AppRuntimeStateStore.clearPausedTripMonitor(context)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, RouteTripMonitorService::class.java).apply {
                action = ACTION_STOP
            }
            runCatching {
                context.startService(intent)
            }
        }
    }
}

data class TrackingSession(
    val provider: String,
    val routeKey: Int,
    val routeId: String?,
    val routeName: String,
    val pathId: Int,
    val pathName: String,
    val appInForeground: Boolean,
    val backgroundLocationAlwaysGranted: Boolean,
    val initialLatitude: Double?,
    val initialLongitude: Double?,
    val boardingStopId: Int?,
    val boardingStopName: String?,
    val destinationStopId: Int?,
    val destinationStopName: String?,
    val stops: List<TrackingStop>,
    val familyRouteIds: List<String> = emptyList(),
    /** Full-width ids as Flutter holds them; only for launch payloads. */
    val boardingLaunchStopId: Long? = null,
    val destinationLaunchStopId: Long? = null,
    /** Epoch milliseconds of the fix behind the initial position, when known. */
    val initialLocationTimestampMs: Long? = null,
) {
    val realtimeRouteIds: List<String>
        get() = (listOfNotNull(routeId) + familyRouteIds).map { it.trim() }
            .filter { it.isNotEmpty() }.distinct()
}

data class TrackingStop(
    val stopId: Int,
    val stopName: String,
    val sequence: Int,
    val lat: Double,
    val lon: Double,
    val rawStopId: String? = null,
    val liveData: LiveStopState? = null,
    /** Full-width id as Flutter holds it; only for launch payloads. */
    val launchStopId: Long = 0L,
)

data class LiveStopState(
    val seconds: Int?,
    val message: String?,
    /** Every vehicle the stop's feed names, including buses still on their way. */
    val vehicleIds: List<String>,
    val etaEntries: List<LiveEtaEntry> = emptyList(),
    /** Only the vehicles the feed places at this stop right now. */
    val busesAtStop: List<String> = emptyList(),
)

data class LiveEtaEntry(
    val seconds: Int?,
    val message: String?,
    val vehicleId: String?,
)

data class TrackingSnapshot(
    val title: String,
    val content: String,
    val subText: String,
    val progressMax: Int?,
    val progressValue: Int?,
    val shortCriticalText: String? = null,
    val hasBoarded: Boolean = false,
    val boardingName: String? = null,
    val boardingEtaText: String? = null,
    val boardingEtaSeconds: Int? = null,
    val boardingStopsAway: Int? = null,
    val boardingDistanceMeters: Double? = null,
    val boardingVehicleId: String? = null,
    val boardingVehiclePassedStop: Boolean = false,
    val boardingPromptEligible: Boolean = false,
    val destinationName: String? = null,
    val remainingStops: Int? = null,
    val destinationDistanceMeters: Double? = null,
    val passedDestinationByStops: Int? = null,
    val nearestStopDistanceMeters: Double? = null,
    val hasRouteValidProgress: Boolean = false,
)

data class VehicleCandidate(
    val vehicleId: String,
    val stopIndex: Int,
    val distanceMeters: Double,
    val etaSeconds: Int?,
)

data class UserMovementState(
    val routeIndexDelta: Int = 0,
    val isTransitLike: Boolean = false,
    val sampleAdvanced: Boolean = false,
)

data class RideStateUpdate(
    val hasBoarded: Boolean = false,
    val boardingVehiclePassedStop: Boolean = false,
    val boardingPromptEligible: Boolean = false,
)
