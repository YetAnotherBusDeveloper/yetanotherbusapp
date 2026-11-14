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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
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

    @Volatile
    private var backend: (String) -> String? = { null }

    @Before
    fun setUp() {
        controller = Robolectric.buildService(RouteTripMonitorService::class.java).create()
        service = controller.get()
        shadow = Shadow.extract(service)
        // No test reaches the real backend; each one says what it answers.
        service.fetchBackendJsonText = { path -> backend(path) }
    }

    @After
    fun tearDown() {
        service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 99)
        controller.destroy()
        assertTrue(ioExecutor().awaitTermination(5, TimeUnit.SECONDS))
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
        val initial = tripWithDestination() + mapOf("routeId" to "TXG1")
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
        service.onStartCommand(startIntent(tripWithDestination()), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)

        service.onStartCommand(command("NOT_BOARDED"), 0, 3)

        assertFalse(ride(service).hasBoarded)
        assertEquals(BoardingEvidence.NONE, ride(service).evidence)
    }

    @Test
    fun switchingRouteRebuildsTheRideState() {
        service.onStartCommand(startIntent(tripWithDestination()), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)

        service.onStartCommand(
            startIntent(tripWithDestination() + mapOf("routeKey" to 7, "routeName" to "7")),
            0,
            3,
        )

        assertFalse("a different route is a different trip", ride(service).hasBoarded)
        assertFalse(ride(service).boardingPromptDue)
    }

    @Test
    fun keepingTheSameTripDoesNotRebuildTheRide() {
        val session = tripWithDestination() + mapOf("routeId" to "TXG1")
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
        val route = threeStopSession() + mapOf("routeId" to "TXG1")
        val withBoardingStop = route + mapOf(
            "boardingStopId" to 1,
            "boardingStopName" to "一站",
        )
        // With and without a boarding stop chosen: both used to be reported as
        // "still waiting" however the ride had been confirmed.
        for (waiting in listOf(withBoardingStop, route)) {
            service.onStartCommand(startIntent(waiting), 0, 1)
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            assertTrue(ride(service).hasBoarded)

            val paused = awaitPause()

            assertEquals("boarded_no_destination", paused.reason)
            val prompt = shadowOf(service.getSystemService(NotificationManager::class.java))
                .getNotification(6022)
            assertNotNull("the rider must be asked where they get off", prompt)
            assertEquals("已偵測上車", prompt.extras.getString(Notification.EXTRA_TITLE))

            // The rider answers by choosing a stop. By now they are stops away,
            // and the bus that called at the boarding stop half a minute ago
            // is someone else's.
            val calledAt = nowSeconds() - 30
            backend = { path ->
                if (path.endsWith("/realtime/buses")) {
                    busFeed("NEXT-BUS", stopsOf(waiting).first(), pathId = 0, gpsTimeSeconds = calledAt)
                } else {
                    null
                }
            }
            service.onStartCommand(
                startIntent(waiting + mapOf("destinationStopId" to 3, "destinationStopName" to "三站")),
                0,
                3,
            )

            assertTrue("choosing a destination continues the same ride", ride(service).hasBoarded)
            assertEquals(BoardingEvidence.USER_CONFIRMED, ride(service).evidence)
            assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))

            fetchLiveData()
            assertTrue(ride(service).hasBoarded)
            assertNull(
                "a bus at the boarding stop now is not the one boarded back then",
                ride(service).trackedVehicleId,
            )
            backend = { null }

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

    @Test
    fun theEtaRollingOverToAPlatedLaterBusStillRaisesTheQuestion() {
        // The bus at the stop has no position feed, so the ETA rolling over is
        // the only sign it left. The next bus is ten minutes out and its ETA
        // entry carries a plate, which used to read as "a bus is here".
        var stopFeed = stopFeed(eta = 0, plate = "AAA-001")
        backend = { path -> if (path.endsWith("/realtime")) stopFeed else "[]" }
        val session = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        service.onStartCommand(startIntent(session), 0, 1)
        fetchLiveData()
        assertEquals(0L, ride(service).boardingCheckId)

        stopFeed = stopFeed(eta = 600, plate = "BBB-002")
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        fetchLiveData()

        assertTrue(
            "the departure must be registered so the rider can be asked",
            ride(service).boardingCheckId != 0L,
        )
    }

    @Test
    fun onlyTheQuestionsOwnButtonsAnswerTheQuestion() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        for (answersTheQuestion in listOf(false, true)) {
            // Bus A calls at the boarding stop and leaves.
            var busStop = stopsOf(trip).first()
            var gpsTime = nowSeconds()
            backend = { path ->
                if (path.endsWith("/realtime/buses")) {
                    busFeed("BUS-A", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
                } else {
                    null
                }
            }
            service.onStartCommand(startIntent(trip), 0, 1)
            refreshAndDeliverAlerts()
            busStop = stopsOf(trip)[1]
            gpsTime += 20
            ShadowSystemClock.advanceBy(20, TimeUnit.SECONDS)
            refreshAndDeliverAlerts()
            val checkId = ride(service).boardingCheckId
            assertTrue("A's departure must be pending as a question", checkId != 0L)
            val notifications = service.getSystemService(NotificationManager::class.java)

            if (!answersTheQuestion) {
                // Not asked yet. The rider is on another bus, one with no
                // position feed, and says so on the tracking notification.
                assertTrue(notifications.activeNotifications.none { it.id == 6023 })
                service.onStartCommand(buttonIntent(notificationId = 6021, title = "我已上車"), 0, 2)

                assertTrue(ride(service).hasBoarded)
                assertNull("an unseen question's bus is not the rider's", ride(service).trackedVehicleId)
            } else {
                // The question is shown 40 s after the departure. The service
                // reads the JVM wall clock, so the departure is aged instead.
                ReflectionHelpers.setField(
                    ReflectionHelpers.getField<Any>(service, "detector"),
                    "pendingCheckSinceMs",
                    System.currentTimeMillis() - 45_000L,
                )
                refreshAndDeliverAlerts()
                assertFalse(
                    "showing the question must not turn the tracking notification's button into an answer",
                    buttonIntent(notificationId = 6021, title = "我已上車").hasExtra("boarding_check_id"),
                )
                service.onStartCommand(buttonIntent(notificationId = 6023, title = "我已上車"), 0, 2)

                assertEquals("yes to the question about A is a ride on A", "BUS-A", ride(service).trackedVehicleId)
            }
            service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 3)
        }
    }

    @Test
    fun aFailingStopFeedDoesNotSilenceTheVehicleFeed() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            requests += path
            if (path.endsWith("/realtime/buses")) {
                """[{"id":"AAA-001","direction":0,"lat":24.1,"lon":120.6,"time":1700000000}]"""
            } else {
                null
            }
        }
        val session = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        service.onStartCommand(startIntent(session), 0, 1)
        fetchLiveData()

        assertEquals("the bus at the boarding stop must be seen", "AAA-001", ride(service).nextBusVehicleId)

        // And it keeps being fetched while the stop feed sits out its backoff.
        val busFetches = requests.count { it.endsWith("/realtime/buses") }
        val stopFetches = requests.size - busFetches
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        fetchLiveData()

        assertEquals(busFetches + 1, requests.count { it.endsWith("/realtime/buses") })
        assertEquals(stopFetches, requests.count { !it.endsWith("/realtime/buses") })
    }

    @Test
    fun switchingDirectionRebuildsTheRideEvenWithTheSameBoardingStop() {
        val outbound = threeStopSession() + mapOf("boardingStopId" to 2, "destinationStopId" to 3)
        service.onStartCommand(startIntent(outbound), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertTrue(ride(service).hasBoarded)

        val inbound = reversed(outbound) + mapOf("destinationStopId" to 1)
        service.onStartCommand(startIntent(inbound), 0, 3)

        assertFalse("the other direction is a different trip", ride(service).hasBoarded)
        assertEquals(
            "the boarding stop is found on the new direction's stops",
            1,
            ride(service).boardingStopIndex,
        )

        // The same stops in a new order are a new line too, whatever the path id.
        service.onStartCommand(command("MARK_BOARDED"), 0, 4)
        service.onStartCommand(startIntent(inbound + mapOf("stops" to outbound.getValue("stops"))), 0, 5)
        assertFalse(ride(service).hasBoarded)
    }

    @Test
    fun aFetchStillInFlightForTheLastTripDoesNotReachTheNextOne() {
        val first = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 2)
        val anotherRoute = first + mapOf("routeKey" to 2, "routeId" to "TXG2")
        val theOtherDirection = reversed(first)
        for (next in listOf(anotherRoute, theOtherDirection)) {
            val firstStop = stopsOf(next).first()
            val oldFetchStarted = CountDownLatch(1)
            val releaseOldFetch = CountDownLatch(1)
            val answersTheNewTrip = AtomicBoolean(false)
            backend = { path ->
                val wantsBuses = path.endsWith("/realtime/buses")
                when {
                    // The new trip: its bus is a stop back, ten minutes out.
                    answersTheNewTrip.get() && wantsBuses -> busFeed("NEW-001", firstStop)
                    answersTheNewTrip.get() -> stopFeed(eta = 600, plate = "NEW-001", stopId = 2)
                    // The old one: a bus pulling in at the boarding stop.
                    wantsBuses -> busFeed("OLD-001", stopsOf(first)[1])
                    else -> {
                        oldFetchStarted.countDown()
                        releaseOldFetch.await(10, TimeUnit.SECONDS)
                        stopFeed(eta = 0, plate = "OLD-001", stopId = 2)
                    }
                }
            }
            service.onStartCommand(startIntent(first), 0, 1)
            assertTrue("the first trip's fetch never started", oldFetchStarted.await(10, TimeUnit.SECONDS))

            // The rider switches while that request is still out. Both trips
            // share stops, so everything it brings back would fit the new one.
            service.onStartCommand(startIntent(next), 0, 2)
            releaseOldFetch.countDown()
            awaitQueuedRefreshes()
            answersTheNewTrip.set(true)
            fetchLiveData()

            assertEquals(
                "the new trip must see its own vehicles, at once, and none of the old trip's",
                "NEW-001",
                ride(service).nextBusVehicleId,
            )
            assertEquals(
                "the old trip's ETA must not count as a bus arriving, and so later as one leaving",
                0L,
                ride(service).boardingCheckId,
            )
            service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 3)
        }
    }

    @Test
    fun aRebuiltTripHearsOfTheVehiclesOnItsFirstRefresh() {
        // One bus at the middle stop, running the direction about to be chosen.
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                """[{"id":"AAA-001","direction":1,"lat":24.1045,"lon":120.6,"time":1700000000}]"""
            } else {
                null
            }
        }
        val outbound = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 2)
        service.onStartCommand(startIntent(outbound), 0, 1)
        fetchLiveData()
        assertNull("it is the other direction's bus", ride(service).nextBusVehicleId)

        // The route's vehicles were fetched a moment ago, but for a detector
        // that no longer exists; the new one must not wait out that interval.
        service.onStartCommand(startIntent(reversed(outbound)), 0, 2)
        fetchLiveData()

        assertEquals("AAA-001", ride(service).nextBusVehicleId)
    }

    @Test
    fun whatARefreshDecidedForAReplacedTripIsNotActedOn() {
        // On board with nowhere to get off: this trip's refresh ends by pausing
        // the monitor to ask for a destination.
        service.onStartCommand(startIntent(threeStopSession() + mapOf("boardingStopId" to 1)), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        fetchLiveData()

        // Before that is acted on, the rider opens another route.
        val next = tripWithDestination() + mapOf("routeKey" to 7, "routeName" to "7")
        service.onStartCommand(startIntent(next), 0, 3)
        shadowOf(Looper.getMainLooper()).idle()

        assertNull(
            "the pause meant for the old trip must not land on the new one",
            AppRuntimeStateStore.loadPausedTripMonitor(service),
        )
        assertEquals(7, ReflectionHelpers.getField<TrackingSession>(service, "session").routeKey)
    }

    @Test
    fun whatARefreshDecidedBeforeTheRiderAnsweredIsNotActedOn() {
        // Taken for on board with nowhere to get off, so this refresh too ends
        // by pausing the monitor to ask for a destination.
        service.onStartCommand(startIntent(threeStopSession() + mapOf("boardingStopId" to 1)), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        fetchLiveData()

        // Before that is acted on, the rider says they are not on the bus.
        beforeTheNextRefresh {
            service.onStartCommand(command("NOT_BOARDED"), 0, 3)
            shadowOf(Looper.getMainLooper()).idle()
        }

        assertNull(
            "a rider still waiting must not have the monitor paused as though on board",
            AppRuntimeStateStore.loadPausedTripMonitor(service),
        )
        assertNotNull(ReflectionHelpers.getField<TrackingSession?>(service, "session"))
    }

    @Test
    fun whatARefreshDecidedBeforeADestinationWasChosenIsNotActedOn() {
        val boarded = threeStopSession() + mapOf("boardingStopId" to 1)
        service.onStartCommand(startIntent(boarded), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        fetchLiveData()

        // Before the pause for want of a destination lands, the rider picks one.
        beforeTheNextRefresh {
            val chosen = mapOf("destinationStopId" to 3, "destinationStopName" to "三站")
            service.onStartCommand(startIntent(boarded + chosen), 0, 3)
            shadowOf(Looper.getMainLooper()).idle()
        }

        assertNull(
            "the ride now has somewhere to get off, and must carry on to it",
            AppRuntimeStateStore.loadPausedTripMonitor(service),
        )
        assertEquals(3, ReflectionHelpers.getField<TrackingSession>(service, "session").destinationStopId)
    }

    @Test
    fun theStopFeedTheAppHandsOverWhileOpenReachesTheDetector() {
        // With the app open the route screen sends its own copy of the stop feed
        // every few seconds, and the monitor does not fetch one of its own.
        fun update(eta: Int, plate: String): Intent {
            val session = threeStopSession()
            val stops = stopsOf(session).map { stop ->
                stop + mapOf(
                    "liveData" to mapOf("eta" to eta, "etas" to listOf(mapOf("plate" to plate, "eta" to eta))),
                )
            }
            return startIntent(session + mapOf("boardingStopId" to 1, "stops" to stops))
        }
        service.onStartCommand(update(eta = 0, plate = "AAA-001"), 0, 1)
        refreshRide()
        assertEquals(0L, ride(service).boardingCheckId)

        service.onStartCommand(update(eta = 600, plate = "BBB-002"), 0, 2)
        refreshRide()

        assertTrue(
            "the bus leaving must be noticed from the app's copy of the feed too",
            ride(service).boardingCheckId != 0L,
        )
    }

    @Test
    fun skippingTheDestinationStillRaisesTheOvershootAlert() {
        jumpPastDestination()
        val arrivalAt = ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs")
        assertTrue("passing the destination must start the arrival clock", arrivalAt > 0L)

        // The service uses the JVM wall clock, not Robolectric's uptime. Age
        // its recorded baseline instead of waiting for the real deadline.
        val beforeDeadline = System.currentTimeMillis() - 30_000L
        ReflectionHelpers.setField(service, "arrivalDetectedAtMs", beforeDeadline)
        refreshAndDeliverAlerts()
        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))
        assertEquals(
            "later overshot snapshots must not restart the clock",
            beforeDeadline,
            ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"),
        )

        ReflectionHelpers.setField(service, "arrivalDetectedAtMs", System.currentTimeMillis() - 45_000L)
        refreshAndDeliverAlerts()

        assertEquals("overshot", AppRuntimeStateStore.loadPausedTripMonitor(service)?.reason)
        val alert = service.getSystemService(NotificationManager::class.java)
            .activeNotifications.single { it.id == 6022 }.notification
        assertEquals("可能坐過站了", alert.extras.getString(Notification.EXTRA_TITLE))
    }

    @Test
    fun skippingTheDestinationStillPausesAfterArrivalGraceWhenOffRoute() {
        // A fix 150 m from the line cannot confirm an overshoot, but arrival's
        // grace period must still finish rather than leaving the trip running.
        jumpPastDestination(longitudeOffset = 0.0015)
        assertTrue(
            "passing the destination must start the arrival clock even off route",
            ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs") > 0L,
        )
        ReflectionHelpers.setField(service, "arrivalDetectedAtMs", System.currentTimeMillis() - 60_000L)
        refreshAndDeliverAlerts()

        assertEquals("arrived", AppRuntimeStateStore.loadPausedTripMonitor(service)?.reason)
    }

    @Test
    fun anOldStopFetchCannotOverwriteANewerAppUpdateForTheSameTrip() {
        assertNewerAppStopFeedWins(stopFeed(eta = 600, plate = "OLD-001"))
    }

    @Test
    fun anOldStopFetchFailureCannotBackOffANewerAppUpdateForTheSameTrip() {
        assertNewerAppStopFeedWins(null)
    }

    @Test
    fun aFamilyVariantCarriesAConfirmedRideWithoutPhoneFixes() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1",
            "familyRouteIds" to listOf("TXG1", "TXG2"),
            "boardingStopId" to 1,
            "destinationStopId" to 3,
        )
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds()
        backend = { path ->
            when (path) {
                "/api/v1/routes/TXG1/realtime/buses" -> "[]"
                "/api/v1/routes/TXG2/realtime/buses" ->
                    busFeed("VARIANT-001", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
                else -> null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        refreshAndDeliverAlerts()
        assertFalse(ride(service).hasUsableLocation)
        assertEquals("VARIANT-001", ride(service).trackedVehicleId)
        assertEquals(2, ride(service).remainingStops)

        busStop = stopsOf(trip)[1]
        gpsTime += 30
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()

        assertEquals(1, ride(service).progressStopIndex)
        assertEquals(1, ride(service).remainingStops)
        val alert = service.getSystemService(NotificationManager::class.java)
            .activeNotifications.single { it.id == 6022 }.notification
        assertEquals("準備下車", alert.extras.getString(Notification.EXTRA_TITLE))
    }

    @Test
    fun familyVehicleFetchesAreThrottledAndFailedRoutesBackOffIndependently() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                requests += path
                if (path.contains("/TXG2/")) null else "[]"
            } else {
                null
            }
        }
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1",
            "familyRouteIds" to listOf("TXG1", "TXG2", "TXG3", "TXG2"),
            "boardingStopId" to 1,
        )
        fun assertFetchCounts(primary: Int, failed: Int, healthy: Int) {
            assertEquals(primary, requests.count { it.contains("/TXG1/") })
            assertEquals(failed, requests.count { it.contains("/TXG2/") })
            assertEquals(healthy, requests.count { it.contains("/TXG3/") })
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        assertFetchCounts(primary = 1, failed = 1, healthy = 1)
        fetchLiveData()
        assertFetchCounts(primary = 1, failed = 1, healthy = 1)

        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        fetchLiveData()
        assertFetchCounts(primary = 2, failed = 1, healthy = 2)

        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        fetchLiveData()
        assertFetchCounts(primary = 3, failed = 2, healthy = 3)
    }

    @Test
    fun aLateFamilyVariantIsFetchedWithoutRefetchingTheFreshPrimary() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                requests += path
                if (path.contains("/TXG1/")) "[]" else busFeed("VARIANT-001", stopsOf(trip).first())
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        awaitQueuedRefreshes()
        val originalDetector = ReflectionHelpers.getField<Any>(service, "detector")
        service.onStartCommand(
            startIntent(trip + mapOf("familyRouteIds" to listOf("TXG1", "TXG2"))), 0, 3,
        )
        fetchLiveData()

        assertTrue(originalDetector === ReflectionHelpers.getField<Any>(service, "detector"))
        assertTrue(ride(service).hasBoarded)
        assertEquals("VARIANT-001", ride(service).trackedVehicleId)
        assertEquals(1, requests.count { it.contains("/TXG1/") })
        assertEquals(1, requests.count { it.contains("/TXG2/") })
    }

    @Test
    fun aRemovedFamilyVariantsInFlightResponseCannotReachTheConfirmedRide() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "familyRouteIds" to listOf("TXG2"),
            "boardingStopId" to 1, "destinationStopId" to 3,
        )
        val variantFetchStarted = CountDownLatch(1)
        val releaseVariantFetch = CountDownLatch(1)
        backend = { path ->
            when (path) {
                "/api/v1/routes/TXG1/realtime/buses" -> "[]"
                "/api/v1/routes/TXG2/realtime/buses" -> {
                    variantFetchStarted.countDown()
                    check(releaseVariantFetch.await(10, TimeUnit.SECONDS)) { "variant request was never released" }
                    busFeed("REMOVED", stopsOf(trip)[2])
                }
                else -> null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        try {
            assertTrue(variantFetchStarted.await(10, TimeUnit.SECONDS))
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            val originalDetector = ReflectionHelpers.getField<Any>(service, "detector")
            service.onStartCommand(startIntent(trip + mapOf("familyRouteIds" to emptyList<String>())), 0, 3)
            assertTrue(originalDetector === ReflectionHelpers.getField<Any>(service, "detector"))
        } finally {
            releaseVariantFetch.countDown()
        }
        awaitQueuedRefreshes()
        // A second confirmation would pick any leaked position at the stop.
        service.onStartCommand(command("MARK_BOARDED"), 0, 4)
        awaitQueuedRefreshes()
        assertNull(ride(service).trackedVehicleId)
        val refreshState = ReflectionHelpers.getField<Map<String, Any>>(service, "busFeedRefreshByRoute")
        assertFalse("an obsolete family response must not repopulate its cache", "TXG2" in refreshState)
    }

    @Test
    fun aTrackedBusRaisesAnOvershootAlertWithoutPhoneFixes() {
        assertBusOnlyOvershoot(stalePhoneFix = false)
    }

    @Test
    fun aStaleFarAwayPhoneFixDoesNotHideATrackedBusOvershoot() {
        assertBusOnlyOvershoot(stalePhoneFix = true)
    }

    @Test
    fun manualBoardingWaitsForTheActualBusInsteadOfAnEarlierBusPastTheDestination() {
        val stops = (0..5).map { index ->
            mapOf(
                "stopId" to index + 1, "stopName" to "stop-$index", "sequence" to index + 1,
                "lat" to 24.1 + index * 0.0045, "lon" to 120.6,
            )
        }
        val trip = sessionPayload() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 4, "stops" to stops,
        )
        var actualStop: Map<String, Any?>? = null
        var gpsTime = nowSeconds()
        var actualGpsTime = gpsTime
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                val reports = org.json.JSONArray(busFeed("EARLIER", stops[5], pathId = 0, gpsTimeSeconds = gpsTime))
                actualStop?.let { stop ->
                    reports.put(
                        org.json.JSONArray(busFeed("ACTUAL", stop, pathId = 0, gpsTimeSeconds = actualGpsTime))
                            .getJSONObject(0),
                    )
                }
                reports.toString()
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        refreshAndDeliverAlerts()

        assertTrue(ride(service).hasBoarded)
        assertNull(ride(service).trackedVehicleId)
        assertNull(ride(service).passedDestinationByStops)
        assertEquals(0L, ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"))
        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))

        // The feed catches up half a minute later, with the fix the rider's
        // bus made at the stop just before they confirmed.
        actualStop = stops.first()
        gpsTime += 30
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("ACTUAL", ride(service).trackedVehicleId)
        assertEquals(0, ride(service).progressStopIndex)

        actualStop = stops[1]
        gpsTime += 30
        actualGpsTime = gpsTime
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("ACTUAL", ride(service).trackedVehicleId)
        assertEquals(2, ride(service).remainingStops)
        assertNull(ride(service).passedDestinationByStops)
        assertEquals(0L, ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"))
        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))
        val alert = service.getSystemService(NotificationManager::class.java)
            .activeNotifications.single { it.id == 6022 }.notification
        assertEquals("1 快到了", alert.extras.getString(Notification.EXTRA_TITLE))
    }

    @Test
    fun wrongDirectionAndOffRouteVariantsCannotBeConfirmedAsTheRidersBus() {
        for ((pathId, longitudeOffset) in listOf(1 to 0.0, 0 to 0.004)) {
            val trip = threeStopSession() + mapOf(
                "routeId" to "TXG1", "familyRouteIds" to listOf("TXG2"),
                "boardingStopId" to 1, "destinationStopId" to 3,
            )
            val busStop = stopsOf(trip).first() + mapOf("lon" to 120.6 + longitudeOffset)
            backend = { path ->
                when (path) {
                    "/api/v1/routes/TXG1/realtime/buses" -> "[]"
                    "/api/v1/routes/TXG2/realtime/buses" -> busFeed("INVALID", busStop, pathId = pathId)
                    else -> null
                }
            }
            service.onStartCommand(startIntent(trip), 0, 1)
            fetchLiveData()
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            awaitQueuedRefreshes()
            assertTrue(ride(service).hasBoarded)
            assertNull(ride(service).trackedVehicleId)
            assertEquals(-1, ride(service).progressStopIndex)
            service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 3)
        }
    }

    private fun assertBusOnlyOvershoot(stalePhoneFix: Boolean) {
        ShadowSystemClock.advanceBy(10, TimeUnit.MINUTES)
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 2,
        )
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds()
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("TRACKED-001", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        refreshAndDeliverAlerts()
        assertEquals("TRACKED-001", ride(service).trackedVehicleId)
        assertEquals(0L, ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"))
        if (stalePhoneFix) {
            feedFix(stopIndex = 0, ageMinutes = 5, longitudeOffset = 0.01)
        }

        busStop = stopsOf(trip)[2]
        gpsTime += 30
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertFalse(ride(service).hasUsableLocation)
        assertEquals(1, ride(service).passedDestinationByStops)
        assertTrue(ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs") > 0L)

        ReflectionHelpers.setField(service, "arrivalDetectedAtMs", System.currentTimeMillis() - 60_000L)
        refreshAndDeliverAlerts()
        assertEquals("overshot", AppRuntimeStateStore.loadPausedTripMonitor(service)?.reason)
        val alert = service.getSystemService(NotificationManager::class.java)
            .activeNotifications.single { it.id == 6022 }.notification
        assertEquals("可能坐過站了", alert.extras.getString(Notification.EXTRA_TITLE))
    }

    private fun assertNewerAppStopFeedWins(oldResponse: String?) {
        val initial = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val oldFetchStarted = CountDownLatch(1)
        val releaseOldFetch = CountDownLatch(1)
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("CURRENT-001", stopsOf(initial).first())
            } else {
                oldFetchStarted.countDown()
                check(releaseOldFetch.await(10, TimeUnit.SECONDS)) { "old stop request was never released" }
                oldResponse
            }
        }
        service.onStartCommand(startIntent(initial), 0, 1)
        try {
            assertTrue("the old stop request never started", oldFetchStarted.await(10, TimeUnit.SECONDS))
            val originalDetector = ReflectionHelpers.getField<Any>(service, "detector")
            val currentStops = stopsOf(initial).map { stop ->
                stop + mapOf("liveData" to mapOf("eta" to 0))
            }
            service.onStartCommand(startIntent(initial + mapOf("stops" to currentStops)), 0, 2)
            assertTrue(
                "an ordinary update must keep the detector",
                originalDetector === ReflectionHelpers.getField<Any>(service, "detector"),
            )
        } finally {
            releaseOldFetch.countDown()
        }
        awaitQueuedRefreshes()
        refreshRide()

        val stops = ReflectionHelpers.getField<Map<Int, LiveStopState>>(service, "cachedLiveStops")
        assertEquals("the app's arrival is newer than the pending response", 0, stops.getValue(1).seconds)
        assertEquals(
            "an obsolete failure must not back off the current stop feed",
            0L,
            ReflectionHelpers.getField<Long>(service, "liveStopBackoffUntilMs"),
        )
        assertEquals(
            "an old ETA must not invent a departure after the app reported an arrival",
            0L,
            ride(service).boardingCheckId,
        )
        assertEquals(
            "discarding the stop response must not discard valid vehicle positions",
            "CURRENT-001",
            ride(service).nextBusVehicleId,
        )
    }

    private fun jumpPastDestination(longitudeOffset: Double = 0.0) {
        ShadowSystemClock.advanceBy(10, TimeUnit.MINUTES)
        val trip = threeStopSession() + mapOf("boardingStopId" to 1, "destinationStopId" to 2)
        service.onStartCommand(startIntent(trip), 0, 1)
        awaitQueuedRefreshes()
        feedFix(stopIndex = 0, ageMinutes = 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        refreshAndDeliverAlerts()
        assertTrue(ride(service).hasBoarded)
        assertEquals(1, ride(service).remainingStops)
        assertEquals(0L, ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"))

        // No fix at the destination: progress goes straight from before it to
        // the following stop after a gap in location updates.
        feedFix(stopIndex = 2, ageMinutes = 0, longitudeOffset = longitudeOffset)
        refreshAndDeliverAlerts()
        assertEquals(
            "the fix must jump past the destination: ${ride(service)}; " +
                "pause=${AppRuntimeStateStore.loadPausedTripMonitor(service)}",
            1,
            ride(service).passedDestinationByStops,
        )
        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))
    }

    private fun refreshAndDeliverAlerts() {
        // Run exactly this refresh: advancing Android uptime can otherwise make
        // an overdue poll race its main-thread alert with another IO snapshot.
        awaitQueuedRefreshes()
        ReflectionHelpers.getField<android.os.Handler>(service, "mainHandler").removeCallbacksAndMessages(null)
        fetchLiveData()
        shadowOf(Looper.getMainLooper()).idle()
    }

    /** The other direction of [session]: the same stops, called at in the opposite order. */
    private fun reversed(session: Map<String, Any?>): Map<String, Any?> = session + mapOf(
        "pathId" to 1,
        "stops" to stopsOf(session).reversed()
            .mapIndexed { index, stop -> stop + mapOf("sequence" to index + 1) },
    )

    @Suppress("UNCHECKED_CAST")
    private fun stopsOf(session: Map<String, Any?>) = session.getValue("stops") as List<Map<String, Any?>>

    private fun stopFeed(eta: Int, plate: String, stopId: Int = 1) =
        """{"paths":[{"stops":[{"stopid":"$stopId","eta":$eta,"etas":[{"plate":"$plate","eta":$eta}]}]}]}"""

    /** One vehicle at [stop]; direction is unknown unless supplied. */
    /** What tapping the button called [title] on a posted notification sends the service. */
    private fun buttonIntent(notificationId: Int, title: String): Intent {
        val posted = service.getSystemService(NotificationManager::class.java).activeNotifications
        val buttons = posted.firstOrNull { it.id == notificationId }?.notification?.actions.orEmpty()
        val button = buttons.firstOrNull { it.title.toString() == title } ?: throw AssertionError(
            "no \"$title\" on notification $notificationId; posted: " +
                posted.joinToString { n -> "${n.id}${n.notification.actions.orEmpty().map { it.title }}" },
        )
        return shadowOf(button.actionIntent).savedIntent
    }

    /** Vehicles stamp their reports with the same clock the phone runs on. */
    private fun nowSeconds() = System.currentTimeMillis() / 1000

    private fun busFeed(
        vehicleId: String,
        stop: Map<String, Any?>,
        pathId: Int? = null,
        gpsTimeSeconds: Long = nowSeconds(),
    ) = """[{"id":"$vehicleId","direction":$pathId,"lat":${stop["lat"]},"lon":${stop["lon"]},"time":$gpsTimeSeconds}]"""

    /** One refresh as the service runs it, after anything it already queued. */
    private fun fetchLiveData() {
        ioExecutor().submit {
            ReflectionHelpers.callInstanceMethod<Any?>(
                service,
                "refreshTrip",
                ReflectionHelpers.ClassParameter.from(Boolean::class.javaPrimitiveType, false),
            )
        }.get(10, TimeUnit.SECONDS)
    }

    private fun awaitQueuedRefreshes() {
        ioExecutor().submit {}.get(10, TimeUnit.SECONDS)
    }

    /**
     * Runs [block] with the refresh it sets off held back, so that what the
     * last refresh left for the main thread is all that can happen in it.
     */
    private fun beforeTheNextRefresh(block: () -> Unit) {
        val held = CountDownLatch(1)
        ioExecutor().execute { held.await(10, TimeUnit.SECONDS) }
        try {
            block()
        } finally {
            held.countDown()
        }
    }

    private fun ioExecutor(): ExecutorService = ReflectionHelpers.getField(service, "ioExecutor")

    /**
     * A ride confirmed with nowhere to get off is paused within moments to ask
     * for a destination, so tests about a ride that carries on give it one.
     */
    private fun tripWithDestination(): Map<String, Any?> = sessionPayload() + mapOf(
        "destinationStopId" to 1,
        "destinationStopName" to "測試站",
    )

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
    private fun feedFix(stopIndex: Int, ageMinutes: Long, longitudeOffset: Double = 0.0) {
        val (lat, lon) = THREE_STOPS[stopIndex]
        val fix = Location("fused").apply {
            latitude = lat
            longitude = lon + longitudeOffset
            accuracy = 10f
            elapsedRealtimeNanos =
                SystemClock.elapsedRealtimeNanos() - TimeUnit.MINUTES.toNanos(ageMinutes)
            time = System.currentTimeMillis() - TimeUnit.MINUTES.toMillis(ageMinutes)
        }
        ReflectionHelpers.setField(service, "latestLocation", fix)
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
