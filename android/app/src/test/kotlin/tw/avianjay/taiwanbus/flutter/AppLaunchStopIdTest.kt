package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.app.NotificationManager
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.location.Location
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * A stop the user taps has to arrive in Flutter as the id Flutter knows.
 *
 * Stop ids are 64-bit in some feeds (高雄's are 11-12 digits), and Dart keys its
 * stops by the raw value. The native side folds ids to a positive `Int` to join
 * the live feeds, and that folded number used to be what widget and
 * notification taps carried too — naming no stop the Flutter side has, so a
 * 高雄 favourite opened its route with nothing selected.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class AppLaunchStopIdTest {
    private val application: Application get() = RuntimeEnvironment.getApplication()

    @Test
    fun theFullWidthIdSurvivesTheLaunchPayload() {
        assertNotEquals(
            "this id only proves anything if folding changes it",
            RAW_STOP_ID,
            foldStopId(RAW_STOP_ID).toLong(),
        )

        val payload = launchPayloadOf(
            AppLaunchConstants.createRouteDetailIntent(
                context = application,
                provider = "khh",
                routeKey = 100,
                routeId = "KHH100",
                pathId = 0,
                stopId = RAW_STOP_ID,
                destinationPathId = 0,
                destinationStopId = RAW_STOP_ID + 30,
            ),
        )

        assertEquals("khh", payload["provider"])
        assertEquals(RAW_STOP_ID, payload.stopId("stopId"))
        assertEquals(RAW_STOP_ID + 30, payload.stopId("destinationStopId"))
    }

    @Test
    fun idsThatFitInAnIntAreUnchanged() {
        // 台中 and 雙北 ids are small, and must keep arriving exactly as before.
        val payload = launchPayloadOf(
            AppLaunchConstants.createRouteDetailIntent(
                context = application,
                provider = "txg",
                routeKey = 1,
                pathId = 0,
                stopId = 13567L,
            ),
        )

        assertEquals(13567L, payload.stopId("stopId"))
    }

    @Test
    fun aMissingStopIdIsStillAbsentFromThePayload() {
        val payload = launchPayloadOf(
            AppLaunchConstants.createRouteDetailIntent(
                context = application,
                provider = "txg",
                routeKey = 1,
            ),
        )

        assertFalse("no stop chosen means no stop in the payload", payload.containsKey("stopId"))
        assertFalse(payload.containsKey("destinationStopId"))
    }

    @Test
    fun aShortcutPinnedBeforeTheIdsWereWidenedStillOpensItsStop() {
        // A pinned shortcut keeps the intent it was created with for as long as
        // it sits on the home screen, so the extras older builds wrote — these
        // names, holding Ints — are a format that has to stay readable.
        val pinnedByAnOlderBuild = Intent()
            .putExtra("launch_target", "route_detail")
            .putExtra("provider", "txg")
            .putExtra("route_key", 1)
            .putExtra("path_id", 0)
            .putExtra("stop_id", 13567)
            .putExtra("destination_path_id", 0)
            .putExtra("destination_stop_id", 13570)

        val payload = launchPayloadOf(pinnedByAnOlderBuild)

        assertEquals(13567L, payload.stopId("stopId"))
        assertEquals(13570L, payload.stopId("destinationStopId"))
    }

    @Test
    fun tappingAWidgetRowLaunchesWithTheFullWidthId() {
        // The config is what Dart saves: the ids as Dart holds them.
        val config = JSONObject().put(
            "通勤",
            JSONArray().put(
                JSONObject()
                    .put("type", "boarding")
                    .put("provider", "khh")
                    .put("routeKey", 100)
                    .put("pathId", 0)
                    .put("stopId", RAW_STOP_ID)
                    .put("routeId", "KHH100")
                    .put("stopName", "測試站")
                    .put("destinationPathId", 0)
                    .put("destinationStopId", RAW_STOP_ID + 30),
            ),
        ).toString()
        val item = FavoriteGroupWidgetSupport.parseFavoriteGroups(config).getValue("通勤").single()

        assertEquals(
            "the live feed is still looked up by the folded key",
            foldStopId(RAW_STOP_ID),
            item.stopId,
        )

        val tap = FavoriteGroupWidgetSupport.createItemPendingIntent(application, item)
        val payload = launchPayloadOf(shadowOf(tap).savedIntent)

        assertEquals(RAW_STOP_ID, payload.stopId("stopId"))
        assertEquals(RAW_STOP_ID + 30, payload.stopId("destinationStopId"))
    }

    @Test
    fun tappingASmartRouteNotificationLaunchesWithTheFullWidthId() {
        // The stop comes out of the route database Flutter syncs, where the id
        // is stored as text.
        val databaseFile = File(
            application.filesDir.parentFile,
            "app_flutter/.yabus_backend/bus_khh_v2.sqlite",
        )
        databaseFile.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(databaseFile, null).use { database ->
            database.execSQL("CREATE TABLE routes (route_key INTEGER, route_id TEXT, route_name TEXT)")
            database.execSQL("CREATE TABLE paths (route_key INTEGER, path_id INTEGER, path_name TEXT)")
            database.execSQL(
                "CREATE TABLE stops (route_key INTEGER, path_id INTEGER, stop_id TEXT, " +
                    "stop_name TEXT, sequence INTEGER, lon REAL, lat REAL)",
            )
            database.execSQL("INSERT INTO routes VALUES (100, 'KHH100', '100')")
            database.execSQL("INSERT INTO paths VALUES (100, 0, '去程')")
            database.execSQL(
                "INSERT INTO stops VALUES (100, 0, '$RAW_STOP_ID', '測試站', 1, 120.338401, 22.60612)",
            )
        }
        val routeData = requireNotNull(
            SmartRouteNotificationSupport.loadRouteData(application, "khh", 100, "100"),
        )
        val here = Location("test").apply {
            latitude = 22.60612
            longitude = 120.338401
        }
        val nearestStop = requireNotNull(
            SmartRouteNotificationSupport.findNearestStop(here, routeData, pathId = 0),
        )

        assertEquals(
            "the live feed is still looked up by the folded key",
            foldStopId(RAW_STOP_ID),
            nearestStop.stopId,
        )

        SmartRouteNotificationSupport.ensureChannel(application)
        SmartRouteNotificationSupport.showNotification(
            context = application,
            profile = SmartRouteProfile(
                provider = "khh",
                routeKey = 100,
                pathId = 0,
                routeName = "100",
                totalOpens = 5,
                lastOpenedAtMs = 0L,
                totalSelections = 0,
                lastSelectedAtMs = 0L,
                hourlyOpens = mapOf(8 to 5),
                hourlySelections = emptyMap(),
            ),
            routeData = routeData,
            nearestStop = nearestStop,
            liveStop = SmartLiveStop(sec = 120, msg = null),
            distanceMeters = nearestStop.distanceMeters,
            nowMs = 1L,
        )
        val posted = shadowOf(application.getSystemService(NotificationManager::class.java))
            .allNotifications
            .single()
        val payload = launchPayloadOf(shadowOf(posted.contentIntent).savedIntent)

        assertEquals(RAW_STOP_ID, payload.stopId("stopId"))
    }

    private fun launchPayloadOf(intent: Intent): Map<String, Any?> {
        val payload = AppLaunchConstants.extractLaunchPayload(intent)
        assertTrue("expected a launch payload", payload != null)
        return payload!!
    }

    private fun Map<String, Any?>.stopId(key: String): Long? = (this[key] as Number?)?.toLong()

    private companion object {
        /**
         * A real 高雄 stop id. Its low 32 bits are negative, so any path that
         * narrows it to an `Int` — by folding or by truncating — changes it.
         */
        const val RAW_STOP_ID = 101111144601L
    }
}
