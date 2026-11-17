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
                "liveData" to mapOf(
                    "eta" to eta, "observedAtMs" to observedJustNow(),
                    "buses" to listOf(mapOf("id" to vehicle)),
                ),
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
    fun aRidePausedForADestinationComesBackOnTheBusItWasOn() {
        // No phone fix at any point: the bus is the only measure of the ride.
        val waiting = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        var busStop = stopsOf(waiting).first()
        var gpsTime = nowSeconds() - 20
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("TRACKED-001", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(waiting), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertEquals("TRACKED-001", ride(service).trackedVehicleId)

        val paused = awaitPause()
        assertEquals("boarded_no_destination", paused.reason)
        assertEquals("the bus is remembered with the paused ride", "TRACKED-001", paused.rideVehicleId)

        // The rider chooses the last stop. The bus has reached the second.
        busStop = stopsOf(waiting)[1]
        gpsTime += 40
        service.onStartCommand(
            startIntent(waiting + mapOf("destinationStopId" to 3, "destinationStopName" to "三站")),
            0,
            3,
        )
        refreshAndDeliverAlerts()

        val resumed = ride(service)
        assertTrue(resumed.hasBoarded)
        assertFalse(resumed.hasUsableLocation)
        assertEquals("TRACKED-001", resumed.trackedVehicleId)
        assertEquals("its position is the ride's progress again", 1, resumed.remainingStops)
        assertNotNull("and what the destination reminders are worked out from", resumed.destinationDistanceMeters)
        assertTrue(
            "one stop to go: the reminder is due",
            ReflectionHelpers.getField<Int>(service, "destinationAlertStage") >= 1,
        )
    }

    @Test
    fun aPauseTheAppAsksForOnAnotherSessionDoesNotCarryThisRidesBus() {
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3)
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("TRACKED-001", stopsOf(trip).first(), pathId = 0, gpsTimeSeconds = nowSeconds() - 20)
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertEquals("TRACKED-001", ride(service).trackedVehicleId)

        val other = reversed(trip) + mapOf("boardingStopId" to 3, "destinationStopId" to 1)
        service.onStartCommand(
            command("PAUSE_TRIP_MONITOR").putExtra("session_json", org.json.JSONObject(other).toString()),
            0,
            3,
        )

        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service)?.rideVehicleId)
    }

    @Test
    fun theDestinationPromptOpensTheRouteAtTheStopTheRideBeganFrom() {
        fun promptLaunch(waiting: Map<String, Any?>): Map<String, Any?> {
            service.onStartCommand(startIntent(waiting), 0, 1)
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            awaitPause()
            val prompt = shadowOf(service.getSystemService(NotificationManager::class.java)).getNotification(6022)
            assertEquals("已偵測上車", prompt.extras.getString(Notification.EXTRA_TITLE))
            val launch = AppLaunchConstants.extractLaunchPayload(shadowOf(prompt.contentIntent).savedIntent)!!
            service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 3)
            return launch
        }
        val route = threeStopSession() + mapOf("routeId" to "TXG1")

        // Boarded at the second stop. A route screen opened from the prompt
        // takes the stop it is given as the boarding stop, and has to come
        // back with the trip that was paused.
        val launch = promptLaunch(route + mapOf("boardingStopId" to 2, "boardingStopName" to "二站"))
        assertEquals(2L, launch["stopId"])
        assertEquals(0, launch["pathId"])

    }

    @Test
    fun theDestinationPromptNamesNoStopWhenTheRideHadNoBoardingStop() {
        // The first stop of the route would be taken for the boarding stop.
        service.onStartCommand(startIntent(threeStopSession() + mapOf("routeId" to "TXG1")), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        awaitPause()
        val prompt = shadowOf(service.getSystemService(NotificationManager::class.java)).getNotification(6022)
        val launch = AppLaunchConstants.extractLaunchPayload(shadowOf(prompt.contentIntent).savedIntent)!!

        assertFalse(launch.containsKey("stopId"))
        assertEquals(0, launch["pathId"])
    }

    @Test
    fun aRideWithNoBoardingStopStaysPausedUntilItsDestinationIsChosen() {
        val route = threeStopSession() + mapOf("routeId" to "TXG1")
        service.onStartCommand(startIntent(route), 0, 1)
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        assertEquals("boarded_no_destination", awaitPause().reason)

        // The route screen, opened from the prompt or getting a fix at last,
        // fills in the stop nearest the rider and sends the trip again.
        val nearestFilledIn = route + mapOf("boardingStopId" to 2, "boardingStopName" to "二站")
        service.onStartCommand(startIntent(nearestFilledIn), 0, 3)
        assertNull("that is the paused ride still, not a new wait at the second stop", detectorOrNull())
        assertNotNull(AppRuntimeStateStore.loadPausedTripMonitor(service))

        service.onStartCommand(
            startIntent(nearestFilledIn + mapOf("destinationStopId" to 3, "destinationStopName" to "三站")),
            0,
            4,
        )
        assertTrue("choosing a destination continues the ride", ride(service).hasBoarded)
        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))
    }

    private fun detectorOrNull(): Any? = ReflectionHelpers.getField(service, "detector")

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
        assertTrue(
            "a ride with no boarding stop chosen is still that ride once the screen fills one in",
            startedAsBoarded(
                waiting - "boardingStopId", "boarded_no_destination", withDestination + mapOf("boardingStopId" to 2),
            ),
        )
        assertFalse(
            "but not on the other direction",
            startedAsBoarded(
                waiting - "boardingStopId", "boarded_no_destination", reversed(withDestination),
            ),
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
    fun buttonsMadeForAnotherTripDoNotSpeakForThisOne() {
        val outbound = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // Outbound: a bus leaves the boarding stop and the question is shown.
        var busStop = stopsOf(outbound).first()
        var gpsTime = nowSeconds() - 60
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("BUS-A", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(outbound), 0, 1)
        refreshAndDeliverAlerts()
        busStop = stopsOf(outbound)[1]
        gpsTime += 20
        ShadowSystemClock.advanceBy(20, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"), "pendingCheckSinceMs",
            System.currentTimeMillis() - 45_000L,
        )
        refreshAndDeliverAlerts()
        val oldYes = buttonIntent(notificationId = 6023, title = "我已上車")
        val oldNo = buttonIntent(notificationId = 6023, title = "還沒上車")
        val oldUnprompted = buttonIntent(notificationId = 6021, title = "我已上車")

        // The rider turns to the other direction. Taps made on the outbound
        // trip's notifications are delivered only now.
        val inbound = reversed(outbound) + mapOf("boardingStopId" to 3, "destinationStopId" to 1)
        backend = { null }
        service.onStartCommand(startIntent(inbound), 0, 2)
        for (stale in listOf(oldYes, oldUnprompted)) {
            service.onStartCommand(stale, 0, 3)
            assertFalse("yes to the outbound trip is not a ride on the inbound one", ride(service).hasBoarded)
        }

        // On board the inbound bus, with its alerts under way.
        service.onStartCommand(command("MARK_BOARDED"), 0, 4)
        assertTrue(ride(service).hasBoarded)
        ReflectionHelpers.setField(service, "destinationAlertStage", 1)
        service.onStartCommand(oldNo, 0, 5)

        assertTrue("not yet, said of the outbound trip, does not undo this ride", ride(service).hasBoarded)
        assertTrue(ReflectionHelpers.getField(service, "boardingAlertSent"))
        assertEquals(1, ReflectionHelpers.getField<Int>(service, "destinationAlertStage"))
    }

    @Test
    fun aLaterQuestionsButtonsDoNotRewriteAnEarlierOnes() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // The button on a notification is a token the system keeps; what it
        // sends is whatever that token holds when it is tapped.
        fun questionButton(title: String) = service.getSystemService(NotificationManager::class.java)
            .activeNotifications.single { it.id == 6023 }.notification.actions
            .single { it.title.toString() == title }.actionIntent
        fun raiseAQuestion(vehicleId: String): Long {
            var busStop = stopsOf(trip).first()
            var gpsTime = nowSeconds() - 60
            backend = { path ->
                if (path.endsWith("/realtime/buses")) {
                    busFeed(vehicleId, busStop, pathId = 0, gpsTimeSeconds = gpsTime)
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
            ReflectionHelpers.setField(
                ReflectionHelpers.getField<Any>(service, "detector"), "pendingCheckSinceMs",
                System.currentTimeMillis() - 45_000L,
            )
            refreshAndDeliverAlerts()
            return ride(service).boardingCheckId
        }
        val firstQuestion = raiseAQuestion("BUS-A")
        val firstYes = questionButton("我已上車")
        val firstTrip = shadowOf(firstYes).savedIntent.getLongExtra("trip_id", 0L)
        assertTrue(firstTrip != 0L)

        // The trip is stopped and started again, and asks a question of its own.
        service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 2)
        Thread.sleep(5)
        val secondQuestion = raiseAQuestion("BUS-B")
        val secondYes = questionButton("我已上車")
        assertTrue(secondQuestion != firstQuestion)

        assertEquals(
            "the first question's button still answers the first question",
            firstQuestion,
            shadowOf(firstYes).savedIntent.getLongExtra("boarding_check_id", 0L),
        )
        assertEquals(firstTrip, shadowOf(firstYes).savedIntent.getLongExtra("trip_id", 0L))
        assertTrue(shadowOf(secondYes).savedIntent.getLongExtra("trip_id", 0L) != firstTrip)
        // And tapped now, it is not an answer to the second.
        service.onStartCommand(shadowOf(firstYes).savedIntent, 0, 3)
        assertFalse(ride(service).hasBoarded)
        service.onStartCommand(shadowOf(secondYes).savedIntent, 0, 4)
        assertEquals("BUS-B", ride(service).trackedVehicleId)
    }

    /** Starts [trip] with [vehicleId] at the boarding stop, drives it off, and has the question shown. */
    private fun raiseAQuestionAbout(vehicleId: String, trip: Map<String, Any?>): Long {
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds() - 60
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed(vehicleId, busStop, pathId = 0, gpsTimeSeconds = gpsTime)
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
        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"), "pendingCheckSinceMs",
            System.currentTimeMillis() - 45_000L,
        )
        refreshAndDeliverAlerts()
        return ride(service).boardingCheckId
    }

    @Test
    fun yesToAQuestionTheRiderHasSinceAnsweredNoIsNotActedOn() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        assertTrue(raiseAQuestionAbout("BUS-A", trip) != 0L)
        val yes = buttonIntent(notificationId = 6023, title = "我已上車")
        service.onStartCommand(buttonIntent(notificationId = 6023, title = "還沒上車"), 0, 2)
        assertFalse(ride(service).hasBoarded)

        // The same trip, so the button is this trip's — but its question is over.
        service.onStartCommand(yes, 0, 3)

        assertFalse("it was the answer to a question already answered", ride(service).hasBoarded)
        assertFalse(ReflectionHelpers.getField<Boolean>(service, "boardingAlertSent"))
    }

    @Test
    fun theQuestionOnScreenAnswersTheQuestionNowPending() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        val first = raiseAQuestionAbout("BUS-A", trip)
        fun shownQuestion() = buttonIntent(notificationId = 6023, title = "我已上車")
            .getLongExtra("boarding_check_id", 0L)
        assertEquals(first, shownQuestion())

        // Some minutes on, unanswered, another bus leaves: the rider is to be
        // asked afresh, in a while. What is on screen meanwhile is still a
        // question, and tapping it must answer the one that now stands.
        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"), "pendingCheckSinceMs",
            System.currentTimeMillis() - 120_000L,
        )
        val staleYes = buttonIntent(notificationId = 6023, title = "我已上車")
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds() - 30
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("BUS-B", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
            } else {
                null
            }
        }
        ShadowSystemClock.advanceBy(20, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        busStop = stopsOf(trip)[1]
        gpsTime += 20
        ShadowSystemClock.advanceBy(20, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        val afresh = ride(service).boardingCheckId
        assertTrue("asked afresh", afresh != 0L && afresh != staleYes.getLongExtra("boarding_check_id", 0L))
        assertFalse("but not yet due to be", ride(service).boardingPromptDue)

        assertEquals("the buttons on screen are the new question's", afresh, shownQuestion())
        service.onStartCommand(staleYes, 0, 2)
        assertFalse("a tap that was already on its way answers nothing", ride(service).hasBoarded)
        service.onStartCommand(buttonIntent(notificationId = 6023, title = "我已上車"), 0, 3)
        assertTrue(ride(service).hasBoarded)
    }

    @Test
    fun notYetToAQuestionSettledSinceLeavesTheRideAndItsAlertsAlone() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds() - 60
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
        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"), "pendingCheckSinceMs",
            System.currentTimeMillis() - 45_000L,
        )
        refreshAndDeliverAlerts()
        val no = buttonIntent(notificationId = 6023, title = "還沒上車")

        // The rider says they are on board, on the tracking notification; the
        // "not yet" they had tapped on the question a moment earlier arrives
        // after it.
        service.onStartCommand(buttonIntent(notificationId = 6021, title = "我已上車"), 0, 2)
        assertTrue(ride(service).hasBoarded)
        ReflectionHelpers.setField(service, "destinationAlertStage", 1)
        service.onStartCommand(no, 0, 3)

        assertTrue("the question it answered is no longer the one pending", ride(service).hasBoarded)
        assertEquals(1, ReflectionHelpers.getField<Int>(service, "destinationAlertStage"))
    }

    @Test
    fun theAnswerAfterTwoBusesLeftCloseTogetherFollowsNeither() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 2,
        )
        val stops = stopsOf(trip)
        // Both stand at the boarding stop; A leaves, then B right behind it.
        // The service reads the JVM wall clock, which does not move with the
        // test's, so the reports are stamped in the minute leading up to now:
        // a vehicle's clock must never run ahead of the phone's.
        var busA = stops[0]
        var busB = stops[0]
        var gpsTime = nowSeconds() - 60
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeeds(
                    busFeed("BUS-A", busA, pathId = 0, gpsTimeSeconds = gpsTime),
                    busFeed("BUS-B", busB, pathId = 0, gpsTimeSeconds = gpsTime),
                )
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        busA = stops[1]
        gpsTime += 20
        ShadowSystemClock.advanceBy(20, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        val asked = ride(service).boardingCheckId
        assertTrue("A leaving must raise the question", asked != 0L)
        busA = stops[2]
        busB = stops[1]
        gpsTime += 20
        ShadowSystemClock.advanceBy(20, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("B leaving right behind is part of the same question", asked, ride(service).boardingCheckId)

        // The question is shown 40 s after the first departure. The service
        // reads the JVM wall clock, so that is aged instead of waited for.
        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"),
            "pendingCheckSinceMs",
            System.currentTimeMillis() - 45_000L,
        )
        refreshAndDeliverAlerts()
        service.onStartCommand(buttonIntent(notificationId = 6023, title = "我已上車"), 0, 2)
        refreshAndDeliverAlerts()

        // The rider is on B. A, a stop past their destination, is not their bus.
        assertTrue(ride(service).hasBoarded)
        assertNull("the answer is as true of either bus", ride(service).trackedVehicleId)
        assertNull(ride(service).passedDestinationByStops)
        assertEquals(0L, ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"))
        assertNull(AppRuntimeStateStore.loadPausedTripMonitor(service))
    }

    @Test
    fun theBusTheStopFeedPlacesAtTheStopIsTheOneItsRolloverReports() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // A stands at the boarding stop, by both feeds; then it leaves, by both.
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds() - 60
        var stopFeed = stopFeed(eta = 0, plate = "BUS-A")
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("BUS-A", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
            } else {
                stopFeed
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        busStop = stopsOf(trip)[1]
        gpsTime += 20
        stopFeed = stopFeed(eta = 600, plate = "BBB-002")
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertTrue(ride(service).boardingCheckId != 0L)

        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"),
            "pendingCheckSinceMs",
            System.currentTimeMillis() - 45_000L,
        )
        refreshAndDeliverAlerts()
        service.onStartCommand(buttonIntent(notificationId = 6023, title = "我已上車"), 0, 2)

        assertEquals(
            "the rollover was tied to A by its plate, so it is no second bus",
            "BUS-A",
            ride(service).trackedVehicleId,
        )
    }

    @Test
    fun twoBusesTheStopFeedPlacesAtTheStopLeaveItsRolloverUnnamed() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // Only A at the stop; then A and B; then the ETA rolls over.
        var stopFeed = realStopFeed(atStop = listOf("BUS-A"), onTheWay = listOf("BUS-B" to 300))
        backend = { path -> if (path.endsWith("/realtime/buses")) "[]" else stopFeed }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        stopFeed = realStopFeed(atStop = listOf("BUS-A", "BUS-B"))
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        stopFeed = realStopFeed(onTheWay = listOf("CCC-003" to 600))
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertTrue(ride(service).boardingCheckId != 0L)
        answerTheQuestionWithYes()

        assertTrue(ride(service).hasBoarded)
        assertNull("either of the two may be the bus that left", ride(service).trackedVehicleId)
    }

    @Test
    fun aBusTheFeedFlagsAsArrivingIsAtTheStopWhateverItsEstimate() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // The vehicle reports itself pulling in with a minute and a half
        // still on its estimate — further out than an estimate alone would
        // have counted as a bus being due.
        var stopFeed = realStopFeed(atStop = listOf("AAA-001"), atStopEta = 95)
        backend = { path -> if (path.endsWith("/realtime/buses")) "[]" else stopFeed }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        stopFeed = realStopFeed(onTheWay = listOf("BBB-002" to 811))
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertTrue("the flagged bus was there, and has left", ride(service).boardingCheckId != 0L)
        answerTheQuestionWithYes()

        assertEquals("and it is the one the feed named", "AAA-001", ride(service).trackedVehicleId)
    }

    @Test
    fun busesStillOnTheirWayAreNotBusesAtTheStop() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // As a live 台中 300 response has it: six vehicles in `buses`, the
        // nearest thirteen minutes out, the last three quarters of an hour.
        val comingLater = listOf(
            "BBB-002" to 811, "CCC-003" to 1_231, "DDD-004" to 1_651,
            "EEE-005" to 2_071, "FFF-006" to 2_431, "GGG-007" to 2_791,
        )
        for (laterBuses in listOf(comingLater, comingLater.take(1))) {
            // [named]: whether the feed says which bus is standing at the stop.
            for (named in listOf(true, false)) {
                var stopFeed = realStopFeed(
                    atStop = listOfNotNull("AAA-001".takeIf { named }),
                    onTheWay = laterBuses,
                    unnamedAtStop = !named,
                )
                backend = { path -> if (path.endsWith("/realtime/buses")) "[]" else stopFeed }
                service.onStartCommand(startIntent(trip), 0, 1)
                refreshAndDeliverAlerts()
                assertEquals(0L, ride(service).boardingCheckId)

                // It leaves. Every bus still listed is one that has yet to come.
                stopFeed = realStopFeed(onTheWay = laterBuses)
                ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
                refreshAndDeliverAlerts()
                assertTrue(
                    "the estimate going to ${laterBuses.first().second} s is a bus leaving, " +
                        "whatever `buses` still lists (${laterBuses.size} listed, named=$named)",
                    ride(service).boardingCheckId != 0L,
                )
                answerTheQuestionWithYes()

                assertTrue(ride(service).hasBoarded)
                assertEquals(
                    "a bus yet to arrive is never the one that left",
                    "AAA-001".takeIf { named },
                    ride(service).trackedVehicleId,
                )
                service.onStartCommand(command("STOP_TRIP_MONITOR"), 0, 3)
            }
        }
    }

    @Test
    fun aBusListedForTheStopButStillOnItsWayIsNotAnArrival() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // Nothing is at the stop: one bus is listed for it, a quarter of an
        // hour out, and then its estimate is revised.
        var stopFeed = realStopFeed(onTheWay = listOf("BBB-002" to 811))
        backend = { path -> if (path.endsWith("/realtime/buses")) "[]" else stopFeed }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        stopFeed = realStopFeed(onTheWay = listOf("BBB-002" to 900))
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()

        assertEquals("no bus was here to leave", 0L, ride(service).boardingCheckId)
    }

    @Test
    fun anEstimateThatRanOutBeforeTheTripBeganIsNotABusLeaving() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TPE1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        // As a live 雙北 response has it: an estimate left at -1, explicitly
        // not arriving, with no plate and nothing in `buses`.
        fun stop(eta: Int) = """{"paths":[{"pathid":0,"stops":[{"stopid":"1","eta":$eta,"message":"",""" +
            """"buses":[],"etas":[{"plate":null,"eta":$eta,"is_arriving":false,"source":"tdx","estimated":false}]}]}]}"""
        var stopFeed = stop(-1)
        backend = { path -> if (path.endsWith("/realtime/buses")) "[]" else stopFeed }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        stopFeed = stop(600)
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("nothing was seen to be due at the stop", 0L, ride(service).boardingCheckId)

        // The next bus counts down, runs out and is replaced: that one left.
        for (eta in listOf(40, -1, 900)) {
            stopFeed = stop(eta)
            ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
            refreshAndDeliverAlerts()
        }
        assertTrue("a countdown that ran out and rolled over is a bus leaving", ride(service).boardingCheckId != 0L)
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
            // From here on the backend answers for the new trip; the request
            // being held was asked before, and brings back the old trip's.
            answersTheNewTrip.set(true)
            service.onStartCommand(startIntent(next), 0, 2)
            releaseOldFetch.countDown()
            awaitQueuedRefreshes()
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
        // [atStop] is the bus the feed flags as arriving; [coming] are listed
        // for the stop too, in `buses` and with entries, while still far off.
        fun update(atStop: String?, coming: List<Pair<String, Int>>): Intent {
            val session = threeStopSession()
            val liveData = mapOf(
                "eta" to if (atStop != null) -1 else coming.first().second,
                "observedEta" to if (atStop != null) -1 else coming.first().second,
                "observedAtMs" to observedJustNow(),
                "message" to "",
                "buses" to (listOfNotNull(atStop) + coming.map { it.first }).map { mapOf("id" to it) },
                "etas" to listOfNotNull(
                    atStop?.let { mapOf("plate" to it, "eta" to -1, "message" to null, "is_arriving" to true) },
                ) + coming.map { (plate, eta) ->
                    mapOf("plate" to plate, "eta" to eta, "message" to null, "is_arriving" to false)
                },
            )
            val stops = stopsOf(session).map { stop -> stop + mapOf("liveData" to liveData) }
            return startIntent(session + mapOf("boardingStopId" to 1, "stops" to stops))
        }
        val later = listOf("BBB-002" to 811, "CCC-003" to 1_231)
        service.onStartCommand(update(atStop = "AAA-001", coming = later), 0, 1)
        refreshRide()
        assertEquals(0L, ride(service).boardingCheckId)

        service.onStartCommand(update(atStop = null, coming = later), 0, 2)
        refreshRide()

        assertTrue(
            "the bus leaving must be noticed from the app's copy of the feed too, " +
                "whatever buses that still lists for the stop",
            ride(service).boardingCheckId != 0L,
        )
    }

    @Test
    fun whatTheRouteScreenGoesOnShowingIsNotNewsFromTheFeed() {
        val trip = threeStopSession() + mapOf("boardingStopId" to 1)
        fun arrivalNotedAt() = ReflectionHelpers.getField<Long>(
            ReflectionHelpers.getField<Any>(service, "detector"), "etaArrivingAtMs",
        )
        // A bus at the stop, observed a few seconds ago.
        val arrivalObservedAt = observedJustNow()
        service.onStartCommand(appUpdate(trip, appStop(eta = 0, observedAtMs = arrivalObservedAt)), 0, 1)
        refreshRide()
        val notedAt = arrivalNotedAt()
        assertTrue(notedAt > 0L)

        // A topology-only update: the stop comes as a placeholder. Its null
        // estimate is the screen having nothing to show, not the bus gone.
        Thread.sleep(5)
        service.onStartCommand(appUpdate(trip, null), 0, 2)
        refreshRide()
        assertEquals("no data is not a departure", 0L, ride(service).boardingCheckId)

        // The same observation again, as the screen sends it every few
        // seconds, and counted down meanwhile: nothing the feed has said.
        service.onStartCommand(appUpdate(trip, appStop(eta = 0, observedAtMs = arrivalObservedAt, shownEta = 0)), 0, 3)
        refreshRide()
        assertEquals("the same observation is not the bus still being there", notedAt, arrivalNotedAt())
        assertEquals(0L, ride(service).boardingCheckId)

        // The feed's next word: the estimate has rolled over.
        service.onStartCommand(appUpdate(trip, appStop(eta = 600, observedAtMs = observedJustNow())), 0, 4)
        refreshRide()
        assertTrue("a new observation is taken up", ride(service).boardingCheckId != 0L)
    }

    @Test
    fun anOldObservationShownAgainDoesNotBringABusBackToTheStop() {
        val trip = threeStopSession() + mapOf("boardingStopId" to 1)
        // The screen's refreshes have been failing for five minutes, and it
        // still shows the bus that was at the stop then.
        val longAgo = System.currentTimeMillis() - 300_000L
        service.onStartCommand(appUpdate(trip, appStop(eta = 0, observedAtMs = longAgo)), 0, 1)
        refreshRide()
        // Then one succeeds, and shows the next bus ten minutes away.
        service.onStartCommand(appUpdate(trip, appStop(eta = 600, observedAtMs = observedJustNow())), 0, 2)
        refreshRide()

        assertEquals("that bus left five minutes ago, not now", 0L, ride(service).boardingCheckId)
    }

    @Test
    fun aStopTheScreenHasOnlyOldDataForIsNotNewsBecauseAnotherStopIs() {
        val trip = threeStopSession() + mapOf("boardingStopId" to 1)
        // Each stop says when it was observed. The boarding stop's refreshes
        // have been failing for five minutes and it still shows the bus that
        // was there then; the stop after it is up to date.
        val longAgo = System.currentTimeMillis() - 300_000L
        service.onStartCommand(
            appUpdate(
                trip,
                appStop(eta = 0, observedAtMs = longAgo),
                nextStop = appStop(eta = 200, observedAtMs = observedJustNow()),
            ),
            0, 1,
        )
        refreshRide()
        service.onStartCommand(
            appUpdate(
                trip,
                appStop(eta = 600, observedAtMs = observedJustNow()),
                nextStop = appStop(eta = 800, observedAtMs = observedJustNow()),
            ),
            0, 2,
        )
        refreshRide()

        assertEquals("that bus left five minutes ago, not now", 0L, ride(service).boardingCheckId)
    }

    @Test
    fun anObservationOlderThanOneAlreadyTakenIsNotTheEstimateRollingOver() {
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val seenByTheScreen = observedJustNow()
        // The monitor's own fetch is answered from a cache made before the
        // screen's: the bus the screen saw at the stop had yet to arrive.
        val before = (seenByTheScreen - 20_000L) / 1_000L
        val stopFetches = java.util.concurrent.atomic.AtomicInteger()
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                "[]"
            } else {
                stopFetches.incrementAndGet()
                """{"paths":[{"pathid":0,"stops":[{"stopid":"1","eta":600,"message":"",""" +
                    """"eta_reference_at":$before,"buses":[{"id":"BBB-002"}],""" +
                    """"etas":[{"plate":"BBB-002","eta":600,"is_arriving":false}]}]}]}"""
            }
        }
        service.onStartCommand(appUpdate(trip, appStop(eta = 0, observedAtMs = seenByTheScreen)), 0, 1)
        refreshAndDeliverAlerts()
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()

        assertEquals(1, stopFetches.get())
        assertEquals("nothing was seen to leave: that was the stop before the bus came", 0L, ride(service).boardingCheckId)
    }

    @Test
    fun theSameObservationSentAgainDoesNotPutOffTheMonitorsOwnFetch() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            requests += path
            if (path.endsWith("/realtime/buses")) "[]" else realStopFeed(onTheWay = listOf("BBB-002" to 420))
        }
        fun stopFetches() = requests.count { !it.endsWith("/realtime/buses") }
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)

        // The screen is answered from the backend's cache: every update it
        // sends carries the observation the last one did, and a recent one.
        val current = appStop(eta = 500, observedAtMs = observedJustNow())
        service.onStartCommand(appUpdate(trip, current), 0, 1)
        refreshAndDeliverAlerts()
        assertEquals("the first time, it is news, and stands in for a fetch", 0, stopFetches())
        for (round in 1..3) {
            ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
            beforeTheNextRefresh { service.onStartCommand(appUpdate(trip, current), 0, 1 + round) }
            refreshAndDeliverAlerts()
        }
        assertEquals("after that it is not, and the monitor's own fetch falls due as usual", 3, stopFetches())
    }

    @Test
    fun aTripBegunOnOldDataFromTheScreenFetchesItsOwnAtOnce() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            requests += path
            if (path.endsWith("/realtime/buses")) "[]" else realStopFeed(onTheWay = listOf("BBB-002" to 420))
        }
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        // The screen's refreshes were already failing when the trip began.
        val kept = appStop(eta = 500, observedAtMs = System.currentTimeMillis() - 200_000L, shownEta = 410)
        service.onStartCommand(appUpdate(trip, kept), 0, 1)
        refreshAndDeliverAlerts()

        assertEquals(1, requests.count { !it.endsWith("/realtime/buses") })
        val shown = ReflectionHelpers.getField<Map<Int, LiveStopState>>(service, "cachedLiveStops").getValue(1)
        assertEquals("what was fetched is what is shown, not the screen's old copy", 420, shown.seconds)
    }

    /** The family's stop feed: what each of two routes says of the boarding stop, and when. */
    private fun familyStopFeed(
        main: Pair<Int?, Long>,
        variant: Pair<Int?, Long>,
    ): (String) -> String? = { path ->
        fun route(estimate: Pair<Int?, Long>) =
            """{"paths":[{"pathid":0,"stops":[{"stopid":"1","eta":${estimate.first},"message":"",""" +
                """"eta_reference_at":${estimate.second},"buses":[],""" +
                """"etas":[{"plate":null,"eta":${estimate.first},"is_arriving":false}]}]}]}"""
        when {
            path.endsWith("/realtime/buses") -> "[]"
            path.contains("batchroutes/") ->
                """{"routes":{"TXG1":${route(main)},"TXG2":${route(variant)}}}"""
            path.endsWith("/TXG2/stops") ->
                """{"paths":[{"pathid":0,"stops":[{"stopid":"1","name":"一站",""" +
                    """"lat":${THREE_STOPS[0].first},"lon":${THREE_STOPS[0].second}}]}]}"""
            else -> null
        }
    }

    @Test
    fun aBusOneRouteOfTheFamilyHasDueIsDueWhateverAnotherRoutesEstimateSays() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "familyRouteIds" to listOf("TXG1", "TXG2"), "boardingStopId" to 1,
        )
        // One route's estimate ran out some time ago, with nothing counting
        // down to it. The other's has a bus due this moment.
        val t = nowSeconds() - 30
        backend = familyStopFeed(main = -1 to t, variant = 0 to t)
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        assertEquals(0L, ride(service).boardingCheckId)

        // Both roll over to the bus after.
        backend = familyStopFeed(main = 600 to t + 20, variant = 600 to t + 20)
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertTrue("the bus that was due has left", ride(service).boardingCheckId != 0L)
    }

    @Test
    fun aRouteOfTheFamilyNotHeardFromAgainIsNotItsBusArrivingAgain() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "familyRouteIds" to listOf("TXG1", "TXG2"), "boardingStopId" to 1,
        )
        // The variant has a bus due. The route itself has one ten minutes off.
        val t = nowSeconds() - 60
        backend = familyStopFeed(main = 600 to t, variant = 0 to t)
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        fun dueAt() = ReflectionHelpers.getField<Long>(
            ReflectionHelpers.getField<Any>(service, "detector"), "etaArrivingAtMs",
        )
        val firstDue = dueAt()
        assertTrue(firstDue != 0L)

        // Only the route itself is observed again. The variant's estimate is
        // the one already taken, and is not a bus due all over again.
        Thread.sleep(15)
        backend = familyStopFeed(main = 580 to t + 20, variant = 0 to t)
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("nothing new was said of a bus due", firstDue, dueAt())
        assertEquals("nor has it left: nothing new was said of that either", 0L, ride(service).boardingCheckId)

        // Then the variant is, and its bus has gone.
        backend = familyStopFeed(main = 560 to t + 40, variant = 900 to t + 40)
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertTrue(ride(service).boardingCheckId != 0L)
    }

    @Test
    fun aRouteOfTheFamilyLongNotHeardFromNoLongerHoldsItsBusAtTheStop() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "familyRouteIds" to listOf("TXG1", "TXG2"), "boardingStopId" to 1,
        )
        // The variant's bus is due — as of an observation nearly a minute and
        // a half old, and the last there will be of it.
        val t = nowSeconds()
        backend = familyStopFeed(main = 600 to t - 30, variant = 0 to t - 88)
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        assertEquals(0L, ride(service).boardingCheckId)

        Thread.sleep(3_000)
        backend = familyStopFeed(main = 580 to t - 10, variant = 0 to t - 88)
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertTrue(
            "what the variant last said is too old to go on meaning a bus at the stop",
            ride(service).boardingCheckId != 0L,
        )
    }

    @Test
    fun theSameObservationFromTheScreenAndFromTheMonitorsOwnFetchIsOneObservation() {
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val observedAt = (nowSeconds() - 5) * 1_000L
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                "[]"
            } else {
                """{"paths":[{"pathid":0,"stops":[{"stopid":"1","eta":0,"message":"",""" +
                    """"eta_reference_at":${observedAt / 1_000L},"buses":[],""" +
                    """"etas":[{"plate":null,"eta":0,"is_arriving":false}]}]}]}"""
            }
        }
        service.onStartCommand(appUpdate(trip, appStop(eta = 0, observedAtMs = observedAt)), 0, 1)
        refreshAndDeliverAlerts()
        fun dueAt() = ReflectionHelpers.getField<Long>(
            ReflectionHelpers.getField<Any>(service, "detector"), "etaArrivingAtMs",
        )
        val firstDue = dueAt()
        assertTrue(firstDue != 0L)

        // The monitor's own fetch falls due and is answered from the same
        // backend snapshot the screen had.
        Thread.sleep(15)
        ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("it is the route's one observation, whichever way it came", firstDue, dueAt())
    }

    @Test
    fun newsOfOtherStopsDoesNotPutOffFetchingTheBoardingStop() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            requests += path
            if (path.endsWith("/realtime/buses")) "[]" else realStopFeed(onTheWay = listOf("BBB-002" to 420))
        }
        fun stopFetches() = requests.count { !it.endsWith("/realtime/buses") }
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)

        // The screen has nothing for the boarding stop, and news of the next
        // one every time.
        for (round in 0..3) {
            if (round > 0) {
                ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
            }
            beforeTheNextRefresh {
                service.onStartCommand(
                    appUpdate(trip, null, nextStop = appStop(eta = 300, observedAtMs = observedJustNow())),
                    0, 1 + round,
                )
            }
            refreshAndDeliverAlerts()
        }
        assertEquals("the boarding stop is fetched every time it falls due", 4, stopFetches())
    }

    @Test
    fun whatTheMonitorFetchedIsNotReplacedByAnEarlierObservationFromTheScreen() {
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val fetchedAt = nowSeconds() - 5
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                "[]"
            } else {
                """{"paths":[{"pathid":0,"stops":[{"stopid":"1","eta":420,"message":"",""" +
                    """"eta_reference_at":$fetchedAt,"buses":[],"etas":[]}]}]}"""
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        refreshAndDeliverAlerts()
        fun shown() = ReflectionHelpers.getField<Map<Int, LiveStopState>>(service, "cachedLiveStops").getValue(1).seconds
        assertEquals(420, shown())

        // The screen is a refresh behind: recent, but from before that.
        service.onStartCommand(
            appUpdate(trip, appStop(eta = 500, observedAtMs = (fetchedAt - 15) * 1_000L)), 0, 2,
        )
        assertEquals(420, shown())
    }

    @Test
    fun theBoardingStopIsNewsWhenItIsEvenIfAnotherStopWasObservedLater() {
        val trip = threeStopSession() + mapOf("boardingStopId" to 1)
        // The screen's stops are not all observed together. The stop after
        // the boarding stop is already twenty seconds ahead of it.
        val t = System.currentTimeMillis() - 40_000L
        val ahead = appStop(eta = 300, observedAtMs = t + 20_000L)
        service.onStartCommand(appUpdate(trip, appStop(eta = 0, observedAtMs = t), nextStop = ahead), 0, 1)
        refreshRide()
        // The boarding stop catches up: its bus has gone. Nothing else is newer.
        service.onStartCommand(
            appUpdate(trip, appStop(eta = 600, observedAtMs = t + 10_000L), nextStop = ahead), 0, 2,
        )
        refreshRide()

        assertTrue("the boarding stop's own estimate rolled over", ride(service).boardingCheckId != 0L)
        val shown = ReflectionHelpers.getField<Map<Int, LiveStopState>>(service, "cachedLiveStops").getValue(1)
        assertEquals("and it is what the monitor shows", 600, shown.seconds)
    }

    @Test
    fun anAnswerForARouteSinceDroppedFromTheFamilyAndPutBackIsNotThisRequestsAnswer() =
        theRequestFromBeforeARouteWasDroppedAndPutBackEnds { "[]" }

    @Test
    fun aFailureForARouteSinceDroppedFromTheFamilyAndPutBackIsNotThisRequestsFailure() =
        theRequestFromBeforeARouteWasDroppedAndPutBackEnds { error("not something the fetch expects") }

    private fun theRequestFromBeforeARouteWasDroppedAndPutBackEnds(itsAnswer: () -> String) {
        val withVariant = threeStopSession() + mapOf(
            "routeId" to "TXG1",
            "familyRouteIds" to listOf("TXG1", "TXG2"),
            "boardingStopId" to 1,
            "destinationStopId" to 3,
        )
        val withoutIt = withVariant + mapOf("familyRouteIds" to listOf("TXG1"))
        val variantRequests = java.util.concurrent.atomic.AtomicInteger()
        val firstAsked = CountDownLatch(1)
        val releaseFirst = CountDownLatch(1)
        val releaseLater = CountDownLatch(1)
        backend = { path ->
            when {
                path == "/api/v1/routes/TXG2/realtime/buses" ->
                    if (variantRequests.incrementAndGet() == 1) {
                        firstAsked.countDown()
                        releaseFirst.await(20, TimeUnit.SECONDS)
                        itsAnswer()
                    } else {
                        releaseLater.await(20, TimeUnit.SECONDS)
                        "[]"
                    }
                path.endsWith("/realtime/buses") -> "[]"
                else -> null
            }
        }
        try {
            service.onStartCommand(startIntent(withVariant), 0, 1)
            assertTrue(firstAsked.await(10, TimeUnit.SECONDS))
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            val theRide = ReflectionHelpers.getField<Any>(service, "detector")
            // The screen loses the variant for a moment and finds it again.
            service.onStartCommand(startIntent(withoutIt), 0, 3)
            service.onStartCommand(startIntent(withVariant), 0, 4)
            assertTrue("it is the same ride throughout", ReflectionHelpers.getField<Any>(service, "detector") === theRide)
            awaitOnMainThread("the variant being asked for again") {
                refreshWithoutWaiting()
                variantRequests.get() == 2
            }

            // The first request is answered with the second still out, and
            // nothing else: every other request has come back by now.
            awaitOnMainThread("only the two requests being out") { service.feedFetchesInFlight.get() == 2 }
            releaseFirst.countDown()
            awaitOnMainThread("the first request ending") { service.feedFetchesInFlight.get() == 1 }
            ShadowSystemClock.advanceBy(90, TimeUnit.SECONDS)
            refreshWithoutWaiting()
            // Requests go out on threads of their own; whatever else this
            // refresh asked for comes back, and one request is left out.
            awaitOnMainThread("no request but the one already out") { service.feedFetchesInFlight.get() == 1 }
            assertEquals("the request now out is still out, and is not sent a third time", 2, variantRequests.get())
        } finally {
            releaseFirst.countDown()
            releaseLater.countDown()
        }
        awaitQueuedRefreshes()
    }

    @Test
    fun theMonitorFetchesForItselfWhileTheRouteScreenHasNothingNew() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            requests += path
            if (path.endsWith("/realtime/buses")) "[]" else realStopFeed(onTheWay = listOf("BBB-002" to 420))
        }
        fun stopFetches() = requests.count { !it.endsWith("/realtime/buses") }
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)

        // What the screen has is current: the monitor does not fetch it again.
        service.onStartCommand(appUpdate(trip, appStop(eta = 500, observedAtMs = observedJustNow())), 0, 1)
        refreshAndDeliverAlerts()
        assertEquals(0, stopFetches())

        // Its refreshes begin to fail. It goes on sending what it has, every
        // few seconds; that must not keep putting off the monitor's own fetch.
        val kept = appStop(eta = 500, observedAtMs = System.currentTimeMillis() - 200_000L, shownEta = 410)
        for (round in 1..3) {
            ShadowSystemClock.advanceBy(25, TimeUnit.SECONDS)
            beforeTheNextRefresh { service.onStartCommand(appUpdate(trip, kept), 0, 1 + round) }
            refreshAndDeliverAlerts()
        }
        assertEquals("one fetch for each time the stop feed fell due", 3, stopFetches())
        val shown = ReflectionHelpers.getField<Map<Int, LiveStopState>>(service, "cachedLiveStops").getValue(1)
        assertEquals("and what was fetched is what is shown, not the screen's old copy", 420, shown.seconds)
    }

    @Test
    fun aBusNamedAtStopsItHasYetToReachIsNotShownAsHavingReachedThem() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "boardingStopId" to 1, "destinationStopId" to 3,
        )
        fun progress() = service.getSystemService(NotificationManager::class.java)
            .activeNotifications.single { it.id == 6021 }.notification.extras.getInt(Notification.EXTRA_PROGRESS)
        // The feed names the tracked bus at each stop still ahead of it, with
        // its estimate there. [reached] is the stop it is flagged arriving at.
        fun stopFeedNamingTheBus(reached: Int?) = (2..3).joinToString(
            ",", prefix = """{"paths":[{"pathid":0,"stops":[""", postfix = "]}]}",
        ) { stopId ->
            val eta = if (stopId == reached) -1 else 450 * (stopId - 1)
            """{"stopid":"$stopId","eta":$eta,"message":"","buses":[{"id":"TRACKED-001"}],""" +
                """"etas":[{"plate":"TRACKED-001","eta":$eta,"is_arriving":${stopId == reached}}]}"""
        }
        var stopFeed = stopFeedNamingTheBus(reached = null)
        var busPath = 0
        var gpsTime = nowSeconds() - 60
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                busFeed("TRACKED-001", stopsOf(trip).first(), pathId = busPath, gpsTimeSeconds = gpsTime)
            } else {
                stopFeed
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        service.onStartCommand(command("MARK_BOARDED"), 0, 2)
        refreshAndDeliverAlerts()
        assertEquals("TRACKED-001", ride(service).trackedVehicleId)

        // No phone fix, and the vehicle's position stops being usable.
        busPath = 1
        gpsTime += 30
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals("TRACKED-001", ride(service).trackedVehicleId)
        assertEquals(-1, ride(service).progressStopIndex)
        assertEquals(
            "an estimate of 450 s for the second stop is not the bus being there",
            100,
            progress(),
        )

        // The feed has it arriving at the second stop: that much is known.
        stopFeed = stopFeedNamingTheBus(reached = 2)
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        refreshAndDeliverAlerts()
        assertEquals(200, progress())
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
                "/api/v1/routes/TXG2/stops" -> variantTopology(trip, 0, 1, 2)
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
    fun aVariantsBusIsNotFollowedToAStopItsRouteNeverCallsAt() {
        rideAVariantToItsTerminalPlatform(variantServesTheDestination = false)
    }

    @Test
    fun aVariantsBusThatCallsAtTheDestinationArrivesAtIt() {
        rideAVariantToItsTerminalPlatform(variantServesTheDestination = true)
    }

    /**
     * The variant shares the first two stops and then runs to a platform
     * seventy metres from this route's last stop — its own, or, when
     * [variantServesTheDestination], one the feeds treat as the same stop.
     */
    private fun rideAVariantToItsTerminalPlatform(variantServesTheDestination: Boolean) {
        run {
            val trip = threeStopSession() + mapOf(
                "routeId" to "TXG1",
                "familyRouteIds" to listOf("TXG1", "TXG2"),
                "boardingStopId" to 1,
                "destinationStopId" to 3,
            )
            var position = stopsOf(trip).first()
            // Every report is made before now, by the clock the phone runs on.
            var gpsTime = nowSeconds() - 85
            backend = { path ->
                when (path) {
                    "/api/v1/routes/TXG1/realtime/buses" -> "[]"
                    "/api/v1/routes/TXG2/realtime/buses" ->
                        busFeed("VARIANT-001", position, pathId = 0, gpsTimeSeconds = gpsTime)
                    "/api/v1/routes/TXG2/stops" ->
                        if (variantServesTheDestination) variantTopology(trip, 0, 1, 2) else variantTopology(trip, 0, 1)
                    else -> null
                }
            }
            service.onStartCommand(startIntent(trip), 0, 1)
            fetchLiveData()
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            refreshAndDeliverAlerts()
            assertEquals("VARIANT-001", ride(service).trackedVehicleId)

            position = stopsOf(trip)[1]
            gpsTime += 40
            ShadowSystemClock.advanceBy(40, TimeUnit.SECONDS)
            refreshAndDeliverAlerts()
            assertEquals("on the stretch the two routes share it is the ride's progress", 1, ride(service).remainingStops)

            // On to its terminal platform, beside this route's last stop.
            val last = stopsOf(trip)[2]
            position = last + mapOf("lon" to (last["lon"] as Double) + 0.0007)
            gpsTime += 40
            ShadowSystemClock.advanceBy(40, TimeUnit.SECONDS)
            refreshAndDeliverAlerts()

            val arrivedAt = ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs")
            if (variantServesTheDestination) {
                assertEquals(0, ride(service).remainingStops)
                assertTrue("a bus that calls at the destination arrives at it", arrivedAt > 0L)
            } else {
                assertEquals("VARIANT-001", ride(service).trackedVehicleId)
                assertFalse(ride(service).hasRouteValidProgress)
                assertTrue("that platform is not the rider's stop", ride(service).remainingStops != 0)
                assertEquals("so nothing has arrived anywhere", 0L, arrivedAt)
            }
        }
    }

    @Test
    fun aVariantWhoseStopsCannotBeFetchedLendsNoVehicles() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1", "familyRouteIds" to listOf("TXG1", "TXG2"), "boardingStopId" to 1,
        )
        val requests = java.util.concurrent.CopyOnWriteArrayList<String>()
        backend = { path ->
            requests += path
            when (path) {
                "/api/v1/routes/TXG1/realtime/buses" -> "[]"
                "/api/v1/routes/TXG2/realtime/buses" -> busFeed("VARIANT-001", stopsOf(trip).first(), pathId = 0)
                else -> null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        fetchLiveData()
        assertNull("where its route runs is not known", ride(service).nextBusVehicleId)

        // And the endpoint is left alone for a while, like any that failed.
        val before = requests.count { it.contains("/TXG2/") }
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        fetchLiveData()
        assertEquals(before, requests.count { it.contains("/TXG2/") })
    }

    @Test
    fun aFamilyEndpointThatHangsDoesNotHoldBackTheRide() {
        val trip = threeStopSession() + mapOf(
            "routeId" to "TXG1",
            "familyRouteIds" to listOf("TXG1", "TXG2"),
            "boardingStopId" to 1,
            "destinationStopId" to 3,
        )
        var busStop = stopsOf(trip).first()
        var gpsTime = nowSeconds() - 85
        val variantRequested = CountDownLatch(1)
        val releaseVariant = CountDownLatch(1)
        var primaryAnswers: CountDownLatch? = null
        backend = { path ->
            when (path) {
                "/api/v1/routes/TXG1/realtime/buses" -> {
                    primaryAnswers?.await(10, TimeUnit.SECONDS)
                    busFeed("MAIN-001", busStop, pathId = 0, gpsTimeSeconds = gpsTime)
                }
                "/api/v1/routes/TXG2/realtime/buses" -> {
                    variantRequested.countDown()
                    releaseVariant.await(20, TimeUnit.SECONDS)
                    null
                }
                else -> null
            }
        }
        try {
            service.onStartCommand(startIntent(trip), 0, 1)
            assertTrue(variantRequested.await(10, TimeUnit.SECONDS))
            // The variant's request is out, and stays out, from here on.
            awaitOnMainThread("the primary route's bus being seen") { ride(service).nextBusVehicleId == "MAIN-001" }
            service.onStartCommand(command("MARK_BOARDED"), 0, 2)
            assertEquals("MAIN-001", ride(service).trackedVehicleId)

            // The bus runs on to the rider's stop. Its endpoint answers at
            // once; nothing may wait for the variant's.
            busStop = stopsOf(trip)[2]
            gpsTime += 80
            ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
            // Exactly this refresh: the poll now overdue would publish too.
            val mainHandler = ReflectionHelpers.getField<android.os.Handler>(service, "mainHandler")
            mainHandler.removeCallbacksAndMessages(null)
            // Its answer comes after the refresh that asked has published
            // what was known before, so only the answer's own publishing can
            // bring the arrival out.
            primaryAnswers = CountDownLatch(1)
            refreshWithoutWaiting()
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(0L, ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs"))
            primaryAnswers!!.countDown()
            awaitOnMainThread("arrival, from the endpoint that answered") {
                ReflectionHelpers.getField<Long>(service, "arrivalDetectedAtMs") > 0L
            }
            assertEquals(0, ride(service).remainingStops)

            // Nor does the rider's own position wait for it.
            val (lat, lon) = THREE_STOPS[2]
            val fix = Location("fused").apply {
                latitude = lat
                longitude = lon
                accuracy = 10f
                elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                time = System.currentTimeMillis()
            }
            ReflectionHelpers.setField(service, "latestLocation", fix)
            ReflectionHelpers.callInstanceMethod<Any?>(
                service, "onUserLocation", ReflectionHelpers.ClassParameter.from(Location::class.java, fix),
            )
            assertFalse(ride(service).hasUsableLocation)
            refreshWithoutWaiting()
            assertTrue("the rider's own fix is published at once", ride(service).hasUsableLocation)
            assertTrue("the variant is still out", service.feedFetchesInFlight.get() > 0)
        } finally {
            releaseVariant.countDown()
        }
        awaitQueuedRefreshes()
    }

    @Test
    fun aFeedWithARequestOutIsNotAskedForAgain() {
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val requests = java.util.concurrent.atomic.AtomicInteger()
        val release = CountDownLatch(1)
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                requests.incrementAndGet()
                release.await(20, TimeUnit.SECONDS)
                "[]"
            } else {
                null
            }
        }
        try {
            service.onStartCommand(startIntent(trip), 0, 1)
            repeat(3) {
                ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
                refreshWithoutWaiting()
            }
            assertEquals(1, requests.get())
        } finally {
            release.countDown()
        }
        awaitQueuedRefreshes()
        ShadowSystemClock.advanceBy(30, TimeUnit.SECONDS)
        fetchLiveData()
        assertEquals("once it has been answered the feed is due again as usual", 2, requests.get())
    }

    @Test
    fun aFeedWhoseRequestBlowsUpIsLeftAloneLikeOneThatFailed() {
        val trip = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val requests = java.util.concurrent.atomic.AtomicInteger()
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                requests.incrementAndGet()
                error("not something the fetch expects")
            } else {
                null
            }
        }
        service.onStartCommand(startIntent(trip), 0, 1)
        awaitQueuedRefreshes()
        repeat(3) {
            ShadowSystemClock.advanceBy(5, TimeUnit.SECONDS)
            fetchLiveData()
        }
        assertEquals("it is not asked again on every refresh", 1, requests.get())

        ShadowSystemClock.advanceBy(60, TimeUnit.SECONDS)
        fetchLiveData()
        assertEquals("nor is it left marked as still being fetched", 2, requests.get())
    }

    @Test
    fun aRequestOfTheLastTripThatBlowsUpDoesNotFreeThisTripsFeed() {
        val first = threeStopSession() + mapOf("routeId" to "TXG1", "boardingStopId" to 1)
        val requests = java.util.concurrent.atomic.AtomicInteger()
        val releaseFirst = CountDownLatch(1)
        val releaseSecond = CountDownLatch(1)
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                if (requests.incrementAndGet() == 1) {
                    releaseFirst.await(20, TimeUnit.SECONDS)
                    error("not something the fetch expects")
                }
                releaseSecond.await(20, TimeUnit.SECONDS)
                "[]"
            } else {
                null
            }
        }
        try {
            service.onStartCommand(startIntent(first), 0, 1)
            refreshWithoutWaiting()
            assertEquals(1, requests.get())

            // Another trip on the same route: its own request goes out.
            service.onStartCommand(startIntent(first + mapOf("boardingStopId" to 2)), 0, 2)
            refreshWithoutWaiting()
            awaitOnMainThread("the new trip's request") { requests.get() == 2 }

            // The first trip's request now fails outright, with this one's still out.
            awaitOnMainThread("only the two requests being out") { service.feedFetchesInFlight.get() == 2 }
            releaseFirst.countDown()
            awaitOnMainThread("the first trip's request ending") { service.feedFetchesInFlight.get() == 1 }
            ShadowSystemClock.advanceBy(90, TimeUnit.SECONDS)
            refreshWithoutWaiting()
            awaitOnMainThread("no request but the one already out") { service.feedFetchesInFlight.get() == 1 }
            assertEquals("this trip's feed is still being fetched, and is not asked for again", 2, requests.get())
        } finally {
            releaseFirst.countDown()
            releaseSecond.countDown()
        }
        awaitQueuedRefreshes()
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
        // The variant's bus is at the stop before the rider confirms; the app
        // only hears of it once the variant is known.
        val reportedAt = nowSeconds()
        backend = { path ->
            if (path.endsWith("/realtime/buses")) {
                requests += path
                if (path.contains("/TXG1/")) {
                    "[]"
                } else {
                    busFeed("VARIANT-001", stopsOf(trip).first(), gpsTimeSeconds = reportedAt)
                }
            } else if (path.endsWith("/TXG2/stops")) {
                variantTopology(trip, 0, 1, 2)
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
                "/api/v1/routes/TXG2/stops" -> variantTopology(trip, 0, 1, 2)
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
                stop + mapOf("liveData" to mapOf("eta" to 0, "observedAtMs" to observedJustNow()))
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

    /**
     * The boarding stop as the backend really reports it. `buses` lists every
     * vehicle heading for the stop next, however far off; [atStop] are the
     * plates flagged as arriving, and [onTheWay] those still coming, with
     * their ETAs. [unnamedAtStop] puts a bus at the stop with no plate.
     * [atStopEta] is the estimate the arriving ones carry: run out, as a rule,
     * but the flag comes from the vehicle and can be up before the countdown ends.
     */
    private fun realStopFeed(
        atStop: List<String> = emptyList(),
        onTheWay: List<Pair<String, Int>> = emptyList(),
        unnamedAtStop: Boolean = false,
        atStopEta: Int = -1,
    ): String {
        val buses = (atStop + onTheWay.map { it.first })
            .joinToString(",") { """{"id":"$it","type":"normal","source":"tdx"}""" }
        val etas = (
            atStop.map { """{"plate":"$it","eta":$atStopEta,"is_arriving":true,"source":"tdx","estimated":false}""" } +
                listOfNotNull(
                    """{"plate":null,"eta":-1,"is_arriving":true,"source":"tdx","estimated":false}"""
                        .takeIf { unnamedAtStop },
                ) +
                onTheWay.map { (plate, eta) ->
                    """{"plate":"$plate","eta":$eta,"is_arriving":false,"source":"tdx","estimated":false}"""
                }
            ).joinToString(",")
        val eta = if (atStop.isNotEmpty() || unnamedAtStop) atStopEta else onTheWay.minOfOrNull { it.second }
        return """{"paths":[{"pathid":0,"stops":[{"stopid":"1","eta":$eta,"message":"",""" +
            """"buses":[$buses],"etas":[$etas]}]}]}"""
    }

    /** Raises the pending question as if its 40 s had passed, and answers "I have boarded". */
    private fun answerTheQuestionWithYes() {
        // The service reads the JVM wall clock, so the departure is aged
        // rather than waited for.
        ReflectionHelpers.setField(
            ReflectionHelpers.getField<Any>(service, "detector"),
            "pendingCheckSinceMs",
            System.currentTimeMillis() - 45_000L,
        )
        refreshAndDeliverAlerts()
        service.onStartCommand(buttonIntent(notificationId = 6023, title = "我已上車"), 0, 2)
    }

    private var observations = 0L

    /** When the backend made an observation the app passes on: moments ago, each later than the last. */
    private fun observedJustNow(): Long = System.currentTimeMillis() - 5_000L + observations++

    /** The route screen's update for [session], with [liveData] as its copy of the boarding stop's feed. */
    private fun appUpdate(
        session: Map<String, Any?>,
        liveData: Map<String, Any?>?,
        nextStop: Map<String, Any?>? = null,
    ): Intent {
        val stops = stopsOf(session).mapIndexed { index, stop ->
            stop + mapOf(
                // Every stop comes with live data; for most it is a placeholder.
                "liveData" to if (index == 0 && liveData != null) {
                    liveData
                } else if (index == 1 && nextStop != null) {
                    nextStop
                } else {
                    mapOf("eta" to null, "observedEta" to null, "observedAtMs" to null, "message" to null)
                },
            )
        }
        return startIntent(session + mapOf("stops" to stops))
    }

    /** The boarding stop as the route screen passes it on: [eta] as observed at [observedAtMs]. */
    private fun appStop(eta: Int?, observedAtMs: Long?, shownEta: Int? = eta): Map<String, Any?> = mapOf(
        "eta" to shownEta,
        "observedEta" to eta,
        "observedAtMs" to observedAtMs,
        "message" to "",
        "buses" to emptyList<Any>(),
        "etas" to listOfNotNull(
            eta?.let { mapOf("plate" to null, "eta" to shownEta, "observedEta" to it, "is_arriving" to (it <= 0)) },
        ),
    )

    /** Several vehicles in one response. */
    private fun busFeeds(vararg feeds: String): String =
        feeds.joinToString(prefix = "[", postfix = "]", separator = ",") { it.removeSurrounding("[", "]") }

    /** Vehicles stamp their reports with the same clock the phone runs on. */
    private fun nowSeconds() = System.currentTimeMillis() / 1000

    private fun busFeed(
        vehicleId: String,
        stop: Map<String, Any?>,
        pathId: Int? = null,
        gpsTimeSeconds: Long = nowSeconds(),
    ) = """[{"id":"$vehicleId","direction":$pathId,"lat":${stop["lat"]},"lon":${stop["lon"]},"time":$gpsTimeSeconds}]"""

    /** One refresh as the service runs it, after anything it already queued, with its requests answered. */
    private fun fetchLiveData() {
        refreshWithoutWaiting()
        awaitQueuedRefreshes()
    }

    /** Waits until every refresh queued so far, and every request it sent, has been dealt with. */
    private fun awaitQueuedRefreshes() {
        val fetches = service.feedFetchesInFlight
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
        while (true) {
            ioExecutor().submit {}.get(10, TimeUnit.SECONDS)
            // A response publishes the ride on the IO thread before its
            // request counts as finished.
            if (fetches.get() == 0) {
                ioExecutor().submit {}.get(10, TimeUnit.SECONDS)
                if (fetches.get() == 0) {
                    return
                }
            }
            check(System.nanoTime() < deadline) { "a feed request never finished" }
            Thread.sleep(2)
        }
    }

    /** One refresh, without waiting for the requests it sends to be answered. */
    private fun refreshWithoutWaiting() {
        ioExecutor().submit {
            ReflectionHelpers.callInstanceMethod<Any?>(
                service,
                "refreshTrip",
                ReflectionHelpers.ClassParameter.from(Boolean::class.javaPrimitiveType, false),
            )
        }.get(10, TimeUnit.SECONDS)
    }

    /** Polls, delivering what refreshes leave for the main thread, until [condition] holds. */
    private fun awaitOnMainThread(what: String, condition: () -> Boolean) {
        repeat(400) {
            shadowOf(Looper.getMainLooper()).idle()
            if (condition()) {
                return
            }
            Thread.sleep(10)
        }
        throw AssertionError("never happened: $what")
    }

    /** The stops of [session] that a variant route calls at, as `/routes/{id}/stops` gives them. */
    private fun variantTopology(session: Map<String, Any?>, vararg stopIndices: Int): String =
        stopIndices.joinToString(",", prefix = """{"paths":[{"pathid":0,"stops":[""", postfix = "]}]}") { index ->
            val stop = stopsOf(session)[index]
            """{"stopid":"${stop["stopId"]}","name":"${stop["stopName"]}","lat":${stop["lat"]},"lon":${stop["lon"]}}"""
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

    /**
     * A command as the app or a notification sends it. The boarding buttons
     * speak for the trip they were made for, so those name the current one —
     * as a button on the notification now showing would.
     */
    private fun command(action: String) = Intent(service, RouteTripMonitorService::class.java)
        .setAction("tw.avianjay.taiwanbus.flutter.action.$action")
        .apply {
            if (action == "MARK_BOARDED" || action == "NOT_BOARDED") {
                putExtra("trip_id", ReflectionHelpers.getField<Long>(service, "tripId"))
            }
        }

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
