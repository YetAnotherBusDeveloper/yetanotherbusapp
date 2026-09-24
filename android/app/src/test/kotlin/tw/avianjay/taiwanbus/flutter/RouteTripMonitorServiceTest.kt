package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
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
    fun addingDestinationAfterBoardingKeepsRideAndTrackedVehicle() {
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
        ReflectionHelpers.setField(service, "rideConfirmed", true)
        ReflectionHelpers.setField(service, "trackedBusId", "KKA-1234")
        ReflectionHelpers.setField(service, "destinationAlertStage", 2)

        val destinationSession = initialSession + mapOf(
            "destinationStopId" to 2,
            "destinationStopName" to "下車站",
        )
        service.onStartCommand(startIntent(destinationSession), 0, 2)

        assertTrue(ReflectionHelpers.getField(service, "rideConfirmed"))
        assertEquals("KKA-1234", ReflectionHelpers.getField(service, "trackedBusId"))
        assertEquals(0, ReflectionHelpers.getField(service, "destinationAlertStage"))
    }

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
