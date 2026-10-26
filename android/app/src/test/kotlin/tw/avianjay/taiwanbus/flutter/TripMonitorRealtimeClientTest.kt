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
class TripMonitorRealtimeClientTest {
    @Test
    fun backgroundRefreshBatchesVariantsAndMatchesPhysicalStopsWithDifferentIds() {
        val requests = mutableListOf<String>()
        var seconds = 120
        var vehicle = "FAMILY-001"
        val client = TripMonitorRealtimeClient { path ->
            requests += path
            when (path) {
                "batchroutes/TXG500,TXG501/realtime" -> batch(
                    live("1", 600, "MAIN-001"),
                    live("ALIAS", seconds, vehicle),
                )
                "routes/TXG501/stops" -> topology("ALIAS")
                else -> error("Unexpected request: $path")
            }
        }

        val first = client.fetch(session()).getValue(1)
        assertEquals(120, first.seconds)
        assertNull(first.message)
        assertEquals(listOf("FAMILY-001", "MAIN-001"), first.vehicleIds)
        assertEquals(600, first.etaEntries.first { it.vehicleId == "MAIN-001" }.seconds)
        assertEquals(120, first.etaEntries.first { it.vehicleId == "FAMILY-001" }.seconds)

        seconds = 240
        vehicle = "FAMILY-002"
        val refreshed = client.fetch(session()).getValue(1)
        assertEquals(240, refreshed.seconds)
        assertTrue(refreshed.vehicleIds.contains("FAMILY-002"))
        assertFalse(refreshed.vehicleIds.contains("FAMILY-001"))
        assertEquals(2, requests.count { it.startsWith("batchroutes/") })
        assertEquals(1, requests.count { it.endsWith("/stops") })
    }

    @Test
    fun doesNotMergeTheOppositeDirectionOrADifferentPhysicalSide() {
        for ((direction, latitude) in listOf(1 to 24.1, 0 to 24.11)) {
            val client = TripMonitorRealtimeClient { path ->
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
    fun sharedRawIdCanSupplyFamilyEtaWhenThePrimaryHasNotDeparted() {
        val primary = live("1", null, "")
        primary.getJSONArray("paths").getJSONObject(0).getJSONArray("stops")
            .getJSONObject(0).put("message", "尚未發車")
        val client = TripMonitorRealtimeClient { path ->
            if (path.startsWith("batchroutes/")) {
                batch(primary, live("1", 45, "FAMILY-001"))
            } else {
                topology("1", latitude = 0.0).also {
                    it.getJSONArray("paths").getJSONObject(0).getJSONArray("stops")
                        .getJSONObject(0).put("name", "不同顯示名稱")
                }
            }
        }
        val stop = client.fetch(session()).getValue(1)
        assertEquals(45, stop.seconds)
        assertNull(stop.message)
        assertEquals(listOf("FAMILY-001"), stop.vehicleIds)
    }

    @Test
    fun failedFamilyTopologyIsRetriedWithoutLosingThePrimary() {
        var topologyRequests = 0
        val client = TripMonitorRealtimeClient { path ->
            if (path.startsWith("batchroutes/")) {
                batch(live("1", 600, "MAIN-001"), live("ALIAS", 60, "FAMILY-001"))
            } else {
                topologyRequests++
                if (topologyRequests == 1) null else topology("ALIAS")
            }
        }
        assertEquals(600, client.fetch(session()).getValue(1).seconds)
        assertEquals(60, client.fetch(session()).getValue(1).seconds)
        assertEquals(2, topologyRequests)
    }

    @Test
    fun aRouteWithoutVariantsUsesTheSingleRouteEndpoint() {
        val client = TripMonitorRealtimeClient { path ->
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

    private fun live(id: String, seconds: Int?, vehicle: String, direction: Int = 0) = JSONObject(
        """{"paths":[{"pathid":$direction,"stops":[{
            "stopid":"$id","eta":$seconds,"message":"",
            "buses":[{"id":"$vehicle"}]
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
