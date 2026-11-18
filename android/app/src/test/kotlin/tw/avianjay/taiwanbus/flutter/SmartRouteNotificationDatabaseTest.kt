package tw.avianjay.taiwanbus.flutter

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The reminder reads the same database files the Flutter side keeps, so these
 * build them with the statements those files are actually created by.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class SmartRouteNotificationDatabaseTest {
    private lateinit var context: Context
    private lateinit var databaseDirectory: File

    private val slot = SmartPlanSlot(
        provider = "khh",
        routeKey = 101,
        routeId = "KHH100",
        pathId = 1,
        routeName = "100",
        weekday = 3,
        startMinute = 190,
        endMinute = 250,
        peakMinute = 220,
        validUntilMs = Long.MAX_VALUE,
        stopId = 100100128221,
    )

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        // BusRepository._databaseDirectory(): getDatabasesPath()/.yabus_backend
        databaseDirectory = File(context.getDatabasePath("_").parentFile, ".yabus_backend")
        databaseDirectory.deleteRecursively()
        databaseDirectory.mkdirs()
    }

    private fun createStops(fileName: String = "bus_khh_v2.sqlite") {
        SQLiteDatabase.openOrCreateDatabase(File(databaseDirectory, fileName), null).use { database ->
            database.execSQL(
                """
                CREATE TABLE stops (
                    routeid     TEXT NOT NULL,
                    pathid      INTEGER NOT NULL,
                    seq         INTEGER NOT NULL,
                    stopid      TEXT NOT NULL,
                    name        TEXT NOT NULL,
                    name_en     TEXT,
                    lat         REAL NOT NULL,
                    lon         REAL NOT NULL,
                    PRIMARY KEY (routeid, pathid, seq)
                )
                """.trimIndent(),
            )
            fun insert(routeId: String, pathId: Int, seq: Int, stopId: String, name: String) =
                database.execSQL(
                    "INSERT INTO stops VALUES (?, ?, ?, ?, ?, NULL, ?, ?)",
                    arrayOf<Any>(routeId, pathId, seq, stopId, name, 22.6 + seq / 1000.0, 120.3),
                )
            // Out of order, to show the reader sorts by running order.
            insert("KHH100", 1, 2, "100100128221", "第二站")
            insert("KHH100", 1, 1, "100100128219", "第一站")
            insert("KHH100", 1, 3, "101-11009", "第三站")
            insert("KHH100", 0, 1, "100100128221", "對向")
            insert("KHH200", 1, 1, "999", "別條路線")
        }
    }

    private fun createMetadata(fileName: String = "routes_metadata_v1.sqlite") {
        SQLiteDatabase.openOrCreateDatabase(File(databaseDirectory, fileName), null).use { database ->
            database.execSQL(
                """
                CREATE TABLE routes (
                    routeid        TEXT PRIMARY KEY,
                    name           TEXT NOT NULL,
                    name_en        TEXT,
                    city_code      TEXT NOT NULL,
                    path_name      TEXT,
                    path_name_en   TEXT,
                    operator_names TEXT
                )
                """.trimIndent(),
            )
            database.execSQL(
                """
                CREATE TABLE paths (
                    routeid     TEXT NOT NULL,
                    pathid      INTEGER NOT NULL,
                    name        TEXT NOT NULL,
                    name_en     TEXT,
                    PRIMARY KEY (routeid, pathid),
                    FOREIGN KEY (routeid) REFERENCES routes(routeid) ON DELETE CASCADE
                )
                """.trimIndent(),
            )
            database.execSQL("INSERT INTO routes VALUES ('KHH100', '100', NULL, 'KHH', NULL, NULL, NULL)")
            database.execSQL("INSERT INTO paths VALUES ('KHH100', 0, '往甲', NULL)")
            database.execSQL("INSERT INTO paths VALUES ('KHH100', 1, '往乙', NULL)")
        }
    }

    @Test
    fun readsTheStopsOfOneDirectionFromTheDatabaseTheAppKeeps() {
        createStops()
        createMetadata()

        val data = SmartRouteNotificationSupport.loadRouteData(context, slot)

        assertEquals("往乙", data?.pathName)
        assertEquals(
            listOf("100100128219" to "第一站", "100100128221" to "第二站", "101-11009" to "第三站"),
            data?.stops?.map { it.rawStopId to it.stopName },
        )
        assertEquals(listOf(1, 1, 1), data?.stops?.map { it.pathId })
        assertEquals(22.602, data!!.stops[1].lat, 1e-9)
        assertEquals(120.3, data.stops[1].lon, 1e-9)
        // And the plan's stop is found among them by its full-width id.
        assertEquals(
            "第二站",
            SmartRouteReminderRules.findUsualStop(slot, data.stops)?.stopName,
        )
    }

    @Test
    fun doesWithoutADirectionNameWhenTheMetadataIsMissing() {
        createStops()

        val data = SmartRouteNotificationSupport.loadRouteData(context, slot)

        assertNull(data?.pathName)
        assertEquals(3, data?.stops?.size)
    }

    @Test
    fun readsTheMetadataFileUnderItsOlderName() {
        createStops()
        createMetadata("routes_metadata_v2.sqlite")

        assertEquals(
            "往乙",
            SmartRouteNotificationSupport.loadRouteData(context, slot)?.pathName,
        )
    }

    @Test
    fun hasNothingToOfferWithoutTheProvidersDatabase() {
        createMetadata()

        assertNull(SmartRouteNotificationSupport.loadRouteData(context, slot))
    }

    @Test
    fun hasNothingToOfferForARouteOrDirectionTheDatabaseDoesNotList() {
        createStops()

        assertNull(
            SmartRouteNotificationSupport.loadRouteData(context, slot.copy(routeId = "KHH999")),
        )
        assertNull(SmartRouteNotificationSupport.loadRouteData(context, slot.copy(pathId = 7)))
    }

    @Test
    fun aDatabaseOfAnotherShapeIsNotAnError() {
        // The layout this worker used to query, which the app stopped
        // writing in 2026-04. Reading it must come back empty, not throw.
        SQLiteDatabase.openOrCreateDatabase(
            File(databaseDirectory, "bus_khh_v2.sqlite"),
            null,
        ).use { database ->
            database.execSQL(
                "CREATE TABLE stops (route_key INTEGER, path_id INTEGER, stop_id INTEGER, " +
                    "stop_name TEXT, sequence INTEGER, lon REAL, lat REAL)",
            )
        }

        assertNull(SmartRouteNotificationSupport.loadRouteData(context, slot))
    }

    @Test
    fun aFileThatIsNotADatabaseIsNotAnError() {
        File(databaseDirectory, "bus_khh_v2.sqlite").writeText("half a download")

        assertNull(SmartRouteNotificationSupport.loadRouteData(context, slot))
    }

    @Test
    fun stillFindsADatabaseLeftWhereTheAppUsedToKeepThem() {
        databaseDirectory.deleteRecursively()
        databaseDirectory = File(context.filesDir.parentFile, "app_flutter/.yabus_backend")
        databaseDirectory.deleteRecursively()
        databaseDirectory.mkdirs()
        createStops()

        assertEquals(
            3,
            SmartRouteNotificationSupport.loadRouteData(context, slot)?.stops?.size,
        )
    }
}
