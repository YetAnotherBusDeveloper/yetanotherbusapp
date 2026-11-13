package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Looper
import android.os.SystemClock
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowSystemClock
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import org.robolectric.android.controller.ServiceController
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowService
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(
    sdk = [28, 34],
    application = Application::class,
    shadows = [RecordingTripServiceShadow::class],
)
class RouteTripMonitorServiceTest {
    private lateinit var controller: ServiceController<RouteTripMonitorService>
    private lateinit var service: RouteTripMonitorService
    private lateinit var shadow: RecordingTripServiceShadow

    @Before
    fun setUp() {
        controller = Robolectric.buildService(RouteTripMonitorService::class.java).create()
        service = controller.get()
        shadow = Shadow.extract(service)
    }

    @After
    fun tearDown() {
        service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 99)
        controller.destroy()
        val executor = ReflectionHelpers.getField<ExecutorService>(service, "ioExecutor")
        assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS))
    }

    @Test
    fun creationDoesNotInitializeLocationOrPromoteControlCommands() {
        assertNull(ReflectionHelpers.getField<Any?>(service, "fusedLocationClient"))
        assertEquals(0, shadow.promotionAttempts)

        assertEquals(
            Service.START_NOT_STICKY,
            service.onStartCommand(command("SET_TRIP_MONITOR_APP_FOREGROUND"), 0, 1),
        )
        assertEquals(0, shadow.promotionAttempts)
        assertTrue(shadow.isStoppedBySelf)
    }

    @Test
    fun validStartPromotesBeforeSessionAndLocationInitialization() {
        assertEquals(Service.START_STICKY, service.onStartCommand(startIntent(), 0, 1))

        assertEquals(1, shadow.promotionAttempts)
        assertNull(shadow.sessionAtPromotion)
        assertNull(shadow.locationClientAtPromotion)
        val notification = shadow.startupNotification!!
        assertEquals("正在啟動乘車提醒…", notification.extras.getString(Notification.EXTRA_TEXT))
        assertEquals("trip_monitor_tracking_v2", notification.channelId)
        assertTrue(notification.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertNotNull(
            service.getSystemService(NotificationManager::class.java)
                .getNotificationChannel(notification.channelId),
        )
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION, service.foregroundServiceType)
        }
        assertNotNull(ReflectionHelpers.getField<Any?>(service, "session"))
        assertFalse(shadow.isStoppedBySelf)
    }

    @Test
    fun invalidAndMissingPayloadsPromoteThenStopWithoutLocationInitialization() {
        for (payload in listOf(null, "not-json", "{}", "{\"stops\":[]}")) {
            val intent = command("START_OR_UPDATE_TRIP_MONITOR")
            payload?.let { intent.putExtra("session_json", it) }
            val attemptsBefore = shadow.promotionAttempts

            assertEquals(Service.START_NOT_STICKY, service.onStartCommand(intent, 0, 1))
            assertEquals(attemptsBefore + 1, shadow.promotionAttempts)
            assertStoppedWithoutNotification()
            assertNull(ReflectionHelpers.getField<Any?>(service, "fusedLocationClient"))
        }
    }

    @Test
    fun pausedSessionPromotesBeforeCheckingPauseAndThenStops() {
        val session = RouteTripMonitorService.parseSessionPayload(sessionPayload())!!
        AppRuntimeStateStore.savePausedTripMonitor(service, session, "user")

        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(startIntent(), 0, 1))
        assertEquals(1, shadow.promotionAttempts)
        assertNull(shadow.sessionAtPromotion)
        assertStoppedWithoutNotification()
        assertTrue(AppRuntimeStateStore.isTripMonitorPausedFor(service, session))
    }

    @Test
    fun stickyRestartPromotesThenStopsWithoutSession() {
        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(null, 0, 1))
        assertEquals(1, shadow.promotionAttempts)
        assertStoppedWithoutNotification()
    }

    @Test
    fun rejectedPromotionStopsBeforeSessionOrLocationWork() {
        for (failure in listOf(SecurityException("location revoked"), IllegalStateException("background"))) {
            shadow.promotionFailure = failure
            val attemptsBefore = shadow.promotionAttempts

            assertEquals(Service.START_NOT_STICKY, service.onStartCommand(startIntent(), 0, 1))
            assertEquals(attemptsBefore + 1, shadow.promotionAttempts)
            assertNull(ReflectionHelpers.getField<Any?>(service, "session"))
            assertNull(ReflectionHelpers.getField<Any?>(service, "fusedLocationClient"))
            assertStoppedWithoutNotification()
        }
    }

    @Test
    fun updateKeepsForegroundAndQueuedStartAfterStopPromotesAgain() {
        service.onStartCommand(startIntent(), 0, 1)
        service.onStartCommand(startIntent(), 0, 2)
        assertEquals(1, shadow.promotionAttempts)

        service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 3)
        assertEquals(Service.START_STICKY, service.onStartCommand(startIntent(), 0, 4))
        assertEquals(2, shadow.promotionAttempts)
        assertNull(shadow.sessionAtPromotion)
        assertFalse(shadow.isForegroundStopped)
    }

    @Test
    fun addingDestinationAfterBoardingKeepsTheRide() {
        val initialSession = sessionPayload() + mapOf(
            "routeId" to "TXG1",
            "boardingStopId" to 1,
            "boardingStopName" to "上車站",
            "stops" to listOf(
                mapOf(
                    "stopId" to 1,
                    "stopName" to "上車站",
                    "sequence" to 1,
                    "lat" to 24.1,
                    "lon" to 120.6,
                ),
                mapOf(
                    "stopId" to 2,
                    "stopName" to "下車站",
                    "sequence" to 2,
                    "lat" to 24.2,
                    "lon" to 120.7,
                ),
            ),
        )
        service.onStartCommand(startIntent(initialSession), 0, 1)
        // The user confirms the ride while waiting, exactly as the notification
        // action does.
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)
        ReflectionHelpers.setField(service, "destinationAlertStage", 2)

        val destinationSession = initialSession + mapOf(
            "destinationStopId" to 2,
            "destinationStopName" to "下車站",
        )
        service.onStartCommand(startIntent(destinationSession), 0, 3)

        assertTrue("choosing a destination must not drop the ride", ride(service).hasBoarded)
        assertEquals(BoardingEvidence.USER_CONFIRMED, ride(service).evidence)
        assertEquals(0, ReflectionHelpers.getField(service, "destinationAlertStage"))
    }

    @Test
    fun familySnapshotReplacesPrimaryCacheAndReleasesUnconfirmedVehicle() {
        fun payload(eta: Int, family: List<String>, vehicle: String) = sessionPayload() + mapOf(
            "routeId" to "TXG1",
            "familyRouteIds" to family,
            "stops" to listOf(mapOf(
                "stopId" to 1, "rawStopId" to "RAW-1", "stopName" to "測試站",
                "lat" to 24.1, "lon" to 120.6,
                "liveData" to mapOf("eta" to eta, "buses" to listOf(mapOf("id" to vehicle))),
            )),
        )
        service.onStartCommand(startIntent(payload(600, emptyList(), "MAIN-001")), 0, 1)

        service.onStartCommand(startIntent(payload(60, listOf("TXG1", "TXG2"), "FAMILY-001")), 0, 2)
        val session = ReflectionHelpers.getField<TrackingSession>(service, "session")
        assertEquals(listOf("TXG1", "TXG2"), session.realtimeRouteIds)
        assertEquals("RAW-1", session.stops.single().rawStopId)
        val live = ReflectionHelpers.getField<Map<Int, LiveStopState>>(service, "cachedLiveStops").getValue(1)
        assertEquals(60, live.seconds)
        assertEquals(listOf("FAMILY-001"), live.vehicleIds)
        // The family arriving re-seeds the trip, so no ride survives from the
        // preliminary primary-route response.
        assertFalse(ride(service).hasBoarded)
    }

    @Test
    fun familyChangesDoNotResetConfirmedRide() {
        val initial = sessionPayload() + mapOf("routeId" to "TXG1")
        service.onStartCommand(startIntent(initial), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)

        service.onStartCommand(
            startIntent(initial + mapOf("familyRouteIds" to listOf("TXG1", "TXG2"))),
            0,
            3,
        )

        assertTrue("a confirmed ride must survive the family arriving", ride(service).hasBoarded)
        assertEquals(BoardingEvidence.USER_CONFIRMED, ride(service).evidence)
    }

    @Test
    fun reportingNotBoardedClearsTheRide() {
        service.onStartCommand(startIntent(), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)

        service.onStartCommand(command("NOT_BOARDED"), 0, 3)

        assertFalse(ride(service).hasBoarded)
        assertEquals(BoardingEvidence.NONE, ride(service).evidence)
    }

    @Test
    fun switchingRouteRebuildsTheRideState() {
        service.onStartCommand(startIntent(), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)

        service.onStartCommand(
            startIntent(sessionPayload() + mapOf("routeKey" to 7, "routeName" to "7")),
            0,
            3,
        )

        assertFalse("a different route is a different trip", ride(service).hasBoarded)
        assertFalse(ride(service).boardingPromptDue)
    }

    @Test
    fun keepingTheSameTripDoesNotRebuildTheRide() {
        val session = sessionPayload() + mapOf("routeId" to "TXG1")
        service.onStartCommand(startIntent(session), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)

        // Every refresh the route screen sends carries the same identity, so a
        // rebuild here would wipe the ride the user just confirmed.
        service.onStartCommand(startIntent(session), 0, 3)

        assertTrue("an identical update must not restart the trip", ride(service).hasBoarded)
        assertEquals(BoardingEvidence.USER_CONFIRMED, ride(service).evidence)
    }

    @Test
    fun theWakeLockDoesNotOutliveTheTrip() {
        val lockOf = {
            ReflectionHelpers.getField<android.os.PowerManager.WakeLock?>(service, "wakeLock")
        }

        service.onStartCommand(startIntent(), 0, 1)
        assertNotNull("tracking must hold a wake lock", lockOf())
        assertTrue("the lock must actually be held", lockOf()!!.isHeld)

        service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 2)

        assertNull("a stopped trip must not keep the CPU awake", lockOf())
    }

    @Test
    fun theBoardingStopAndItsLiveEtaMeetOnTheSameKey() {
        // 高雄 stop ids are 64-bit, and the two sides of this join used to
        // compute the key differently — the session wrapped the low 32 bits
        // while the feed hashed the digits — so the live ETA of a 高雄 stop
        // could never be found. Both now fold the raw id the same way.
        //
        // This id is a real one from the 高雄 feed, chosen because its low 32
        // bits are negative: an id that wraps to a positive number would agree
        // with the fold by accident and hide the bug.
        val rawStopId = "101111144601"

        val session = RouteTripMonitorService.parseSessionPayload(
            mapOf(
                "provider" to "khh",
                "routeKey" to 100,
                "routeId" to "KHH100",
                "pathId" to 0,
                "boardingStopId" to rawStopId.toLong(),
                "stops" to listOf(
                    mapOf(
                        "stopId" to rawStopId.toLong(),
                        "stopName" to "測試站",
                        "sequence" to 1,
                        "lat" to 22.60612,
                        "lon" to 120.338401,
                    ),
                ),
            ),
        )
        // The failure this guards against is a silent one: the folded id stops
        // being positive, so the session drops the boarding stop entirely and
        // the live ETA is never consulted. Say that, rather than let it surface
        // as a bare NPE.
        assertNotNull("the session must keep a boarding stop for a 64-bit stop id", session)
        val boardingStopId = requireNotNull(session?.boardingStopId) {
            "the boarding stop was dropped instead of folded to a positive key"
        }
        // The live ETA now arrives through the family fetch, so the join is
        // checked against the same code the service runs.
        val liveStops = TripMonitorFamilyRealtime { path ->
            assertEquals("routes/KHH100/realtime", path)
            org.json.JSONObject(
                """{"paths":[{"pathid":0,"stops":[{"stopid":"$rawStopId","eta":120}]}]}""",
            )
        }.fetch(session!!)

        assertTrue("the boarding stop must fold to a positive key", boardingStopId > 0)
        assertEquals("the session's stop must keep its id", boardingStopId, session.stops.single().stopId)
        assertNotNull(
            "the live ETA must be reachable from the session's boarding stop",
            liveStops[boardingStopId],
        )
        assertEquals(120, liveStops[boardingStopId]!!.seconds)
    }

    @Test
    fun aCachedFixFromMinutesAgoIsNotTreatedAsWhereTheRiderIs() {
        // Robolectric's clock starts at boot; move on so "five minutes ago" exists.
        ShadowSystemClock.advanceBy(10, TimeUnit.MINUTES)
        service.onStartCommand(startIntent(threeStopSession()), 0, 1)

        // What the fused provider hands back first: its cached last location.
        feedFix(stopIndex = 2, ageMinutes = 5)

        assertFalse("a five-minute-old fix is not a usable position", ride(service).hasUsableLocation)
        assertEquals(
            "and must not decide where the trip starts",
            -1,
            ride(service).boardingStopIndex,
        )

        feedFix(stopIndex = 1, ageMinutes = 0)

        assertTrue(ride(service).hasUsableLocation)
        assertEquals("the trip starts where the rider is now", 1, ride(service).boardingStopIndex)
    }

    @Test
    fun theSessionsStartingPositionIsAgedByWhenFlutterMeasuredIt() {
        ShadowSystemClock.advanceBy(10, TimeUnit.MINUTES)
        val (lat, lon) = THREE_STOPS[2]
        service.onStartCommand(
            startIntent(
                threeStopSession() + mapOf(
                    "initialLatitude" to lat,
                    "initialLongitude" to lon,
                    "initialLocationTimestampMs" to System.currentTimeMillis() - 5 * 60_000L,
                ),
            ),
            0,
            1,
        )
        refreshRide()

        assertFalse(ride(service).hasUsableLocation)
        assertEquals(-1, ride(service).boardingStopIndex)
    }

    @Test
    fun boardingWithoutADestinationAsksForOneAndPicksTheRideBackUp() {
        val withBoardingStop = threeStopSession() + mapOf(
            "boardingStopId" to 1,
            "boardingStopName" to "一站",
        )
        // With and without a boarding stop chosen: both used to be reported as
        // "still waiting" however the ride had been confirmed.
        for (waiting in listOf(withBoardingStop, threeStopSession())) {
            service.onStartCommand(startIntent(waiting), 0, 1)
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            assertTrue(ride(service).hasBoarded)

            val paused = awaitPause()

            assertEquals("boarded_no_destination", paused.reason)
            val prompt = shadowOf(service.getSystemService(NotificationManager::class.java))
                .getNotification(6022)
            assertNotNull("the rider must be asked where they get off", prompt)
            assertEquals("已偵測上車", prompt.extras.getString(Notification.EXTRA_TITLE))

            // The rider answers by choosing a stop.
            service.onStartCommand(
                startIntent(waiting + mapOf("destinationStopId" to 3, "destinationStopName" to "三站")),
                0,
                3,
            )

            assertTrue("choosing a destination continues the same ride", ride(service).hasBoarded)
            assertEquals(BoardingEvidence.USER_CONFIRMED, ride(service).evidence)
            assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))

            service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 4)
        }
    }

    @Test
    fun onlyTheRidePausedForADestinationIsPickedBackUp() {
        val waiting = threeStopSession() + mapOf("boardingStopId" to 1)
        val withDestination = waiting + mapOf("destinationStopId" to 3)
        fun startedAsBoarded(
            pausedAs: Map<String, Any?>,
            reason: String,
            resumedAs: Map<String, Any?>,
            pausedMinutesAgo: Long = 1,
        ): Boolean {
            AppRuntimeStateStore.savePausedTripMonitor(
                service,
                RouteTripMonitorService.parseSessionPayload(pausedAs)!!,
                reason,
            )
            // The store stamps the pause with the real clock, so it is aged here.
            service.getSharedPreferences("app_runtime_state", Context.MODE_PRIVATE).edit()
                .putLong(
                    "trip_monitor_paused_at_ms",
                    System.currentTimeMillis() - TimeUnit.MINUTES.toMillis(pausedMinutesAgo),
                )
                .commit()
            service.onStartCommand(startIntent(resumedAs), 0, 1)
            val boarded = ride(service).hasBoarded
            service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 2)
            return boarded
        }

        assertTrue(startedAsBoarded(waiting, "boarded_no_destination", withDestination))
        assertFalse(
            "a pause the rider asked for says nothing about being on board",
            startedAsBoarded(waiting, "user", withDestination),
        )
        assertFalse(
            "another boarding stop is another trip",
            startedAsBoarded(waiting, "boarded_no_destination", withDestination + mapOf("boardingStopId" to 2)),
        )
        assertFalse(
            "an hour on, that ride is over",
            startedAsBoarded(waiting, "boarded_no_destination", withDestination, pausedMinutesAgo = 61),
        )
    }

    @Test
    fun tappingATripNotificationLaunchesWithTheFullWidthStopId() {
        val rawStopId = 101111144601L
        val session = RouteTripMonitorService.parseSessionPayload(
            mapOf(
                "provider" to "khh",
                "routeKey" to 100,
                "pathId" to 0,
                "destinationStopId" to rawStopId,
                "stops" to listOf(
                    mapOf("stopId" to rawStopId, "stopName" to "測試站", "lat" to 22.6, "lon" to 120.3),
                ),
            ),
        )!!
        assertEquals("the feed join still uses the folded key", foldStopId(rawStopId), session.destinationStopId)

        val tap = ReflectionHelpers.callInstanceMethod<PendingIntent>(
            service,
            "createOpenRoutePendingIntent",
            ReflectionHelpers.ClassParameter.from(TrackingSession::class.java, session),
        )
        val payload = AppLaunchConstants.extractLaunchPayload(shadowOf(tap).savedIntent)!!

        assertEquals(rawStopId, (payload["stopId"] as Number).toLong())
    }

    private fun threeStopSession(): Map<String, Any?> = sessionPayload() + mapOf(
        "stops" to THREE_STOPS.mapIndexed { index, (lat, lon) ->
            mapOf(
                "stopId" to index + 1,
                "stopName" to "${"一二三"[index]}站",
                "sequence" to index + 1,
                "lat" to lat,
                "lon" to lon,
            )
        },
    )

    /** Delivers a fix at a stop, as the location callback does, and re-reads the ride. */
    private fun feedFix(stopIndex: Int, ageMinutes: Long) {
        val (lat, lon) = THREE_STOPS[stopIndex]
        val fix = Location("fused").apply {
            latitude = lat
            longitude = lon
            accuracy = 10f
            elapsedRealtimeNanos =
                SystemClock.elapsedRealtimeNanos() - TimeUnit.MINUTES.toNanos(ageMinutes)
            time = System.currentTimeMillis() - TimeUnit.MINUTES.toMillis(ageMinutes)
        }
        ReflectionHelpers.callInstanceMethod<Any?>(
            service,
            "onUserLocation",
            ReflectionHelpers.ClassParameter.from(Location::class.java, fix),
        )
        refreshRide()
    }

    private fun refreshRide() {
        ReflectionHelpers.callInstanceMethod<Any?>(
            service,
            "refreshRideSnapshot",
            ReflectionHelpers.ClassParameter.from(Long::class.javaPrimitiveType, System.currentTimeMillis()),
        )
    }

    /** Lets the service's own refresh loop run until it pauses the trip. */
    private fun awaitPause(): TripMonitorPauseState {
        repeat(100) {
            AppRuntimeStateStore.loadPausedTripMonitor(service)?.let { return it }
            shadowOf(Looper.getMainLooper()).idleFor(500, TimeUnit.MILLISECONDS)
            Thread.sleep(50)
        }
        throw AssertionError("the monitor never paused to ask for a destination")
    }

    private fun ride(service: RouteTripMonitorService): RideSnapshot =
        ReflectionHelpers.getField(service, "latestRide")

    private fun assertStoppedWithoutNotification() {
        assertTrue(shadow.isStoppedBySelf)
        assertTrue(shadow.isForegroundStopped)
        assertNull(shadow.lastForegroundNotification)
        assertTrue(service.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
    }

    private fun command(action: String) = Intent(service, RouteTripMonitorService::class.java)
        .setAction("tw.avianjay.taiwanbus.flutter.action.$action")

    private fun startIntent(payload: Map<String, Any?> = sessionPayload()) =
        command("START_OR_UPDATE_TRIP_MONITOR")
            .putExtra("session_json", org.json.JSONObject(payload).toString())

    private fun sessionPayload(): Map<String, Any?> = mapOf(
        "provider" to "txg",
        "routeKey" to 1,
        "routeName" to "1",
        "pathId" to 0,
        "appInForeground" to true,
        "backgroundLocationAlwaysGranted" to false,
        "stops" to listOf(mapOf("stopId" to 1, "stopName" to "測試站", "lat" to 24.1, "lon" to 120.6)),
    )
}

/** Three stops about 500 m apart, running north. */
private val THREE_STOPS = listOf(24.1000 to 120.6, 24.1045 to 120.6, 24.1090 to 120.6)

@Implements(Service::class)
class RecordingTripServiceShadow : ShadowService() {
    @RealObject
    private lateinit var realService: Service

    var promotionAttempts = 0
    var promotionFailure: RuntimeException? = null
    var sessionAtPromotion: Any? = null
    var locationClientAtPromotion: Any? = null
    var startupNotification: Notification? = null

    @Implementation
    override fun startForeground(id: Int, notification: Notification) {
        promotionAttempts++
        sessionAtPromotion = ReflectionHelpers.getField(realService, "session")
        locationClientAtPromotion = ReflectionHelpers.getField(realService, "fusedLocationClient")
        startupNotification = notification
        promotionFailure?.let { throw it }
        super.startForeground(id, notification)
    }
}
