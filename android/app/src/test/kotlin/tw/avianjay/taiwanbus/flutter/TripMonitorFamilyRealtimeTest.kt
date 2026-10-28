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
