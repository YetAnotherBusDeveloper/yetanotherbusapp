package tw.avianjay.taiwanbus.flutter

import android.content.Context
import androidx.appfunctions.AppFunctionElementNotFoundException
import androidx.appfunctions.AppFunctionInvalidArgumentException
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36], application = YABusApplication::class)
class YabusAppFunctionsTest {
    private lateinit var context: Context
    private lateinit var repository: YabusAssistantFavorites

    @Before
    fun prepare() {
        context = RuntimeEnvironment.getApplication()
        repository = YabusAssistantFavorites(context)
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().clear()
            .putString("flutter.favorite_groups", """{
                "Commute": [
                    {"type":"route","provider":"tpe","routeKey":1,"routeId":"TPE307","routeName":"307"},
                    {"type":"station","provider":"tpe","stationId":"station-1","stationName":"City Hall"},
                    {"provider":"tpe","routeKey":1,"routeId":"TPE307","pathId":1,"stopId":123,
                     "stopName":"City Hall","destinationPathId":1,"destinationStopId":456,"destinationStopName":"Home"}
                ],
                "Weekend": [{"type":"route","provider":"tpe","routeKey":1,"routeId":"TPE307","routeName":"307"}]
            }""").commit()
    }

    @Test
    fun localGroupsAndPaginationPreserveLegacyAndV2Favorites() {
        assertEquals(listOf("Commute", "Weekend"), repository.groups())
        val first = repository.list("Commute", 0, 2)
        assertEquals("android_local", first.source)
        assertEquals(3, first.total)
        assertEquals(2, first.nextOffset)
        assertEquals(listOf("route", "station"), first.items.map { it.type })
        val last = repository.list("Commute", first.nextOffset, 2)
        assertEquals(-1, last.nextOffset)
        assertEquals("boarding", last.items.single().type)
        assertEquals("Home", last.items.single().destinationStopName)
        assertEquals(1, last.items.single().pathId)
    }

    @Test
    fun sameFavoriteInDifferentGroupsHasDifferentIds() {
        val first = repository.list("Commute", 0, 1).items.single()
        val other = repository.list("Weekend", 0, 1).items.single()
        assertNotEquals(first.id, other.id)
        assertEquals("Weekend", repository.find(other.id).first)
    }

    @Test
    fun openActionsRetainStationAndBoardingDestination() {
        val page = repository.list("Commute", 0, 50)
        val station = repository.find(page.items[1].id).second
        val stationPayload = AppLaunchConstants.extractLaunchPayload(repository.intent(station))!!
        assertEquals("station_detail", stationPayload["target"])
        assertEquals("station-1", stationPayload["stationId"])
        val boarding = repository.find(page.items[2].id).second
        val payload = AppLaunchConstants.extractLaunchPayload(repository.intent(boarding))!!
        assertEquals(456, payload["destinationStopId"])
        assertEquals(1, payload["pathId"])
    }

    @Test
    fun removedFavoriteCannotOpenUsingAnOldId() {
        val id = repository.list("Commute", 0, 1).items.single().id
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().clear().commit()
        assertThrows(AppFunctionElementNotFoundException::class.java) { repository.find(id) }
        assertTrue(repository.groups().isEmpty())
    }

    @Test
    fun invalidQueriesAreRejectedAndExtremeOffsetsDoNotOverflow() {
        assertThrows(AppFunctionInvalidArgumentException::class.java) { repository.list("", -1, 20) }
        assertThrows(AppFunctionInvalidArgumentException::class.java) { repository.list("", 0, 51) }
        assertThrows(AppFunctionElementNotFoundException::class.java) { repository.list("Missing", 0, 20) }
        assertTrue(repository.list("", Int.MAX_VALUE, 50).items.isEmpty())
        assertEquals(-1, repository.list("", Int.MAX_VALUE, 50).nextOffset)
    }

    @Test
    fun malformedPreferencesReturnAnEmptyListWithoutExposingRawData() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putString("flutter.favorite_groups", "invalid-json").commit()
        assertTrue(repository.list("", 0, 20).items.isEmpty())
    }
}
