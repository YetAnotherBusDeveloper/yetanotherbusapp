package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.app.NotificationManager
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
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
        val slot = SmartPlanSlot(
            provider = "khh",
            routeKey = 100,
            routeId = "KHH100",
            pathId = 1,
            routeName = "100",
            weekday = 1,
            startMinute = 190,
            endMinute = 250,
            peakMinute = 220,
            validUntilMs = Long.MAX_VALUE,
            stopId = RAW_STOP_ID,
        )
        val databaseFile = File(
            application.getDatabasePath("_").parentFile,
            ".yabus_backend/bus_khh_v2.sqlite",
        )
        databaseFile.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(databaseFile, null).use { database ->
            database.execSQL(
                "CREATE TABLE stops (routeid TEXT, pathid INTEGER, seq INTEGER, stopid TEXT, " +
                    "name TEXT, name_en TEXT, lat REAL, lon REAL, PRIMARY KEY (routeid, pathid, seq))",
            )
            database.execSQL(
                "INSERT INTO stops VALUES ('KHH100', 1, 1, ?, '測試站', NULL, 22.60612, 120.338401)",
                arrayOf(RAW_STOP_ID.toString()),
            )
        }
        val routeData = requireNotNull(SmartRouteNotificationSupport.loadRouteData(application, slot))
        val choice = requireNotNull(
            SmartRouteNotificationSupport.chooseStop(slot, routeData, location = null),
        )
        assertEquals(RAW_STOP_ID.toString(), choice.stop.rawStopId)

        // The feed is joined by the stored string, not the native folded key.
        val feed = """
            {"paths": [{"pathid": 1, "stops": [
                {"stopid": "${foldStopId(RAW_STOP_ID)}", "eta": 300},
                {"stopid": "$RAW_STOP_ID", "eta": 480}
            ]}]}
        """.trimIndent()
        val now = 1775604360000L
        val live = requireNotNull(
            SmartRouteReminderRules.parseLiveStop(feed, slot.pathId, choice.stop.rawStopId, now),
        )
        val decision = requireNotNull(SmartRouteReminderRules.decide(live, choice.distanceMeters))
        assertEquals(480, decision.etaSeconds)

        SmartRouteNotificationSupport.ensureChannel(application)
        SmartRouteNotificationSupport.showNotification(
            context = application,
            slot = slot,
            stop = choice.stop,
            text = SmartRouteReminderRules.buildText(
                routeName = slot.routeName,
                pathName = routeData.pathName,
                stopName = choice.stop.stopName,
                decision = decision,
                distanceMeters = choice.distanceMeters,
                slot = slot,
                dayStartHour = 4,
                nowMs = now,
            ),
            timeoutMs = SmartRouteReminderRules.timeoutMs(decision),
        )
        val posted = shadowOf(application.getSystemService(NotificationManager::class.java))
            .allNotifications
            .single()
        val payload = launchPayloadOf(shadowOf(posted.contentIntent).savedIntent)

        assertEquals("KHH100", payload["routeId"])
        assertEquals(1, payload["pathId"])
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
