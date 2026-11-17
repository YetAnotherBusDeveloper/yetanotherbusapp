package tw.avianjay.taiwanbus.flutter

import android.app.Application
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class TripMonitorFamilyRealtimeTest {
    @Test
    fun backgroundFetchMatchesNearbyVariantStopsAndRefreshesVehicles() {
        val requests = mutableListOf<String>()
        var variantEta = 120
        var variantBus = "FAMILY-001"
        val client = TripMonitorFamilyRealtime { path ->
            requests += path
            when (path) {
                "batchroutes/TXG500,TXG501/realtime" -> batch(
                    live("1", 600, "MAIN-001"), live("ALIAS", variantEta, variantBus),
                )
                "routes/TXG501/stops" -> topology("ALIAS")
                else -> error("unexpected URL: $path")
            }
        }
        val first = client.fetch(session()).getValue(1)
        assertEquals(120, first.seconds)
        assertEquals(600, first.etaEntries.first { it.vehicleId == "MAIN-001" }.seconds)
        assertEquals(120, first.etaEntries.first { it.vehicleId == "FAMILY-001" }.seconds)

        variantEta = 240
        variantBus = "FAMILY-002"
        val second = client.fetch(session()).getValue(1)
        assertEquals(240, second.seconds)
        assertTrue(second.vehicleIds.contains("FAMILY-002"))
        assertFalse(second.vehicleIds.contains("FAMILY-001"))
        assertEquals(2, requests.count { it.startsWith("batchroutes/") })
        assertEquals(1, requests.count { it.endsWith("/stops") })
    }

    @Test
    fun doesNotMixOppositeDirectionOrDifferentPhysicalStop() {
        for ((direction, latitude) in listOf(1 to 24.1, 0 to 24.11)) {
            val client = TripMonitorFamilyRealtime { path ->
                if (path.startsWith("batchroutes/")) {
                    batch(live("1", 600, "MAIN-001"), live("ALIAS", 10, "WRONG", direction))
                } else {
                    topology("ALIAS", direction, latitude)
                }
            }
            val stop = client.fetch(session()).getValue(1)
            assertEquals(600, stop.seconds)
            assertEquals(listOf("MAIN-001"), stop.vehicleIds)
        }
    }

    @Test
    fun matchingRawIdDoesNotRequireCoordinatesOrMatchingNames() {
        val client = TripMonitorFamilyRealtime { path ->
            if (path.startsWith("batchroutes/")) {
                batch(live("1", null, ""), live("1", 45, "FAMILY-001"))
            } else {
                topology("1", latitude = 0.0).also {
                    it.getJSONArray("paths").getJSONObject(0).getJSONArray("stops")
                        .getJSONObject(0).put("name", "不同名字")
                }
            }
        }
        val result = client.fetch(session()).getValue(1)
        assertEquals(45, result.seconds)
        assertNull(result.message)
        assertEquals(listOf("FAMILY-001"), result.vehicleIds)
    }

    @Test
    fun failedTopologyIsRetriedAndPrimaryRemainsAvailable() {
        var calls = 0
        val client = TripMonitorFamilyRealtime { path ->
            if (path.startsWith("batchroutes/")) {
                batch(live("1", 600, "MAIN-001"), live("ALIAS", 60, "FAMILY-001"))
            } else {
                calls++
                if (calls == 1) null else topology("ALIAS")
            }
        }
        assertEquals(600, client.fetch(session()).getValue(1).seconds)
        assertEquals(60, client.fetch(session()).getValue(1).seconds)
        assertEquals(2, calls)
    }

    @Test
    fun aStopSaysWhatTheBackendObservedAndWhen() {
        val fromTheBackend = parseTripMonitorLiveStop(
            JSONObject(
                """{"stopid":"1","eta":-1,"message":"","eta_reference_at":1794376374,
                    "buses":[{"id":"AAA-001"}],
                    "etas":[{"plate":"AAA-001","eta":-1,"is_arriving":true},{"plate":"BBB-002","eta":811,"is_arriving":false}]}""",
            ),
        )
        assertEquals(1_794_376_374_000L, fromTheBackend.observedAtMs)
        assertEquals(-1, fromTheBackend.observations.single().seconds)
        assertEquals(listOf(true, false), fromTheBackend.etaEntries.map { it.isArriving })

        // From the route screen: counted down for display, and saying so.
        val fromTheApp = parseTripMonitorLiveStop(
            JSONObject(
                """{"eta":0,"observedEta":40,"observedAtMs":1794376374123,"message":"",
                    "etas":[{"plate":"AAA-001","eta":0,"observedEta":40,"is_arriving":false}]}""",
            ),
        )
        assertEquals(0, fromTheApp.seconds)
        assertEquals(StopObservation("", 40, 1_794_376_374_123L), fromTheApp.observations.single())
        assertEquals(40, fromTheApp.etaEntries.single().observedSeconds)

        // A placeholder for a stop with nothing to show observed nothing.
        val placeholder = parseTripMonitorLiveStop(JSONObject("""{"eta":null,"observedEta":null,"observedAtMs":null}"""))
        assertNull(placeholder.observedAtMs)
        assertNull(placeholder.observations.single().seconds)

        // A stop the screen merged from a family says what each route observed.
        val merged = parseTripMonitorLiveStop(
            JSONObject(
                """{"eta":40,"observedEta":40,"observedAtMs":1794376374123,"observations":[
                    {"source":"TXG500","eta":-1,"atMs":1794376354000},
                    {"source":"TXG501","eta":40,"atMs":1794376374123}]}""",
            ),
            source = "TXG500",
        )
        assertEquals(
            listOf(
                StopObservation("TXG500", -1, 1_794_376_354_000L),
                StopObservation("TXG501", 40, 1_794_376_374_123L),
            ),
            merged.observations,
        )
    }

    @Test
    fun whatEachRouteObservedOfASharedStopStaysItsOwn() {
        val client = TripMonitorFamilyRealtime { path ->
            if (path.startsWith("batchroutes/")) {
                batch(
                    live("1", 600, "MAIN-001").observedAt(1_794_376_374L),
                    live("ALIAS", -1, "FAMILY-001").observedAt(1_794_376_354L),
                )
            } else {
                topology("ALIAS")
            }
        }
        val stop = client.fetch(session()).getValue(1)
        assertEquals("the badge counts down to the next bus to come", 600, stop.seconds)
        assertEquals(
            "each estimate keeps the moment it was observed at, and neither stands for the other",
            listOf(
                StopObservation("TXG500", 600, 1_794_376_374_000L),
                StopObservation("TXG501", -1, 1_794_376_354_000L),
            ),
            stop.observations,
        )
        assertEquals(
            "a bus listed with no estimate of its own is listed by its route all the same",
            mapOf("MAIN-001" to setOf("TXG500"), "FAMILY-001" to setOf("TXG501")),
            stop.etaEntries.associate { it.vehicleId to it.sources },
        )
    }

    @Test
    fun aBusOneRouteHasArrivingAtASharedStopIsThatRoutesToSay() {
        fun arriving(snapshot: JSONObject, plate: String) = snapshot.apply {
            getJSONArray("paths").getJSONObject(0).getJSONArray("stops").getJSONObject(0)
                .put("eta", -1)
                .put("etas", org.json.JSONArray("""[{"plate":"$plate","eta":-1,"is_arriving":true}]"""))
        }
        val client = TripMonitorFamilyRealtime { path ->
            if (path.startsWith("batchroutes/")) {
                batch(
                    live("1", 600, "MAIN-001").observedAt(1_794_376_374L).apply {
                        getJSONArray("paths").getJSONObject(0).getJSONArray("stops").getJSONObject(0)
                            .put("etas", org.json.JSONArray("""[{"plate":"MAIN-001","eta":600,"is_arriving":false}]"""))
                    },
                    arriving(live("ALIAS", -1, "EAL-5389").observedAt(1_794_376_354L), "EAL-5389"),
                )
            } else {
                topology("ALIAS")
            }
        }
        val stop = client.fetch(session()).getValue(1)
        assertEquals(
            listOf(
                StopObservation("TXG500", 600, 1_794_376_374_000L, arriving = false),
                StopObservation("TXG501", -1, 1_794_376_354_000L, arriving = true),
            ),
            stop.observations,
        )
        assertEquals(
            "and each bus is listed by the route that listed it",
            mapOf("MAIN-001" to setOf("TXG500"), "EAL-5389" to setOf("TXG501")),
            stop.etaEntries.associate { it.vehicleId to it.sources },
        )
    }

    @Test
    fun aBusTwoRoutesListAlikeIsOneBusListedByBoth() {
        fun listing(stopId: String) = live(stopId, 40, "KKA-0002").apply {
            getJSONArray("paths").getJSONObject(0).getJSONArray("stops").getJSONObject(0)
                .put("etas", org.json.JSONArray("""[{"plate":"KKA-0002","eta":40,"is_arriving":true}]"""))
        }
        val client = TripMonitorFamilyRealtime { path ->
            if (path.startsWith("batchroutes/")) batch(listing("1"), listing("ALIAS")) else topology("ALIAS")
        }
        val entry = client.fetch(session()).getValue(1).etaEntries.single()
        assertEquals(setOf("TXG500", "TXG501"), entry.sources)
    }

    @Test
    fun aStopSaysABusIsArrivingByAVehiclesFlagOrItsMessage() {
        fun stop(json: String) = parseTripMonitorLiveStop(JSONObject(json), source = "TXG500").observations.single()
        assertTrue(stop("""{"eta":-1,"etas":[{"plate":"AAA-001","eta":-1,"is_arriving":true}]}""").arriving)
        assertTrue(stop("""{"eta":null,"message":"進站中"}""").arriving)
        assertTrue(stop("""{"eta":null,"message":"即將到站"}""").arriving)
        assertFalse(stop("""{"eta":40,"message":"末班車已過","etas":[{"plate":"AAA-001","eta":40}]}""").arriving)
    }

    @Test
    fun whatTheScreenMergedSaysWhichRouteSaidWhat() {
        val merged = parseTripMonitorLiveStop(
            JSONObject(
                """{"eta":600,"observedEta":600,"observedAtMs":1794376374123,
                    "observations":[
                        {"source":"TXG500","eta":600,"atMs":1794376374123,"arriving":false,"message":null},
                        {"source":"TXG501","eta":-1,"atMs":1794376354000,"arriving":true,"message":null},
                        {"source":"TXG502","eta":null,"atMs":1794376364000,"arriving":false,"message":"進站中"}
                    ],
                    "etas":[
                        {"plate":"MAIN-001","eta":600,"observedEta":600,"is_arriving":false,"routes":["TXG500"]},
                        {"plate":"EAL-5389","eta":-1,"observedEta":-1,"is_arriving":true,
                            "routes":["TXG501","TXG502"]},
                        {"plate":"OLD-001","eta":700,"observedEta":700,"is_arriving":false}
                    ]}""",
            ),
            source = "TXG500",
        )
        assertEquals(listOf(false, true, true), merged.observations.map { it.arriving })
        assertEquals(
            "an entry that names no route is the session's own",
            listOf(setOf("TXG500"), setOf("TXG501", "TXG502"), setOf("TXG500")),
            merged.etaEntries.map { it.sources },
        )
    }

    private fun JSONObject.observedAt(seconds: Long) = apply {
        getJSONArray("paths").getJSONObject(0).getJSONArray("stops").getJSONObject(0).put("eta_reference_at", seconds)
    }

    @Test
    fun singleRouteUsesExistingEndpoint() {
        val client = TripMonitorFamilyRealtime { path ->
            assertEquals("routes/TXG500/realtime", path)
            live("1", 90, "MAIN-001")
        }
        assertEquals(90, client.fetch(session().copy(familyRouteIds = emptyList())).getValue(1).seconds)
    }

    private fun session() = TrackingSession(
        provider = "txg", routeKey = 500, routeId = "TXG500", routeName = "500",
        pathId = 0, pathName = "去程", appInForeground = false,
        backgroundLocationAlwaysGranted = true,
        initialLatitude = 24.1, initialLongitude = 120.6,
        boardingStopId = 1, boardingStopName = "共用站",
        destinationStopId = null, destinationStopName = null,
        stops = listOf(TrackingStop(1, "共用站", 1, 24.1, 120.6, rawStopId = "1")),
        familyRouteIds = listOf("TXG500", "TXG501", "TXG501"),
    )

    private fun live(id: String, seconds: Int?, bus: String, direction: Int = 0) = JSONObject(
        """{"paths":[{"pathid":$direction,"stops":[{
            "stopid":"$id","eta":$seconds,"message":"",
            "buses":[{"id":"$bus"}]
        }]}]}""",
    )

    private fun topology(id: String, direction: Int = 0, latitude: Double = 24.1) = JSONObject(
        """{"paths":[{"pathid":$direction,"stops":[{
            "stopid":"$id","name":"共用站","lat":$latitude,"lon":120.6
        }]}]}""",
    )

    private fun batch(primary: JSONObject, variant: JSONObject) = JSONObject()
        .put("routes", JSONObject().put("TXG500", primary).put("TXG501", variant))
}
