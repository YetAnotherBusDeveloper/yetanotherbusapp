package tw.avianjay.taiwanbus.flutter

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class FavoriteWidgetRenderingTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    @Test
    fun failedStationIsNotReportedAsNoUpcomingBus() {
        // Blank provider fails locally, with no network request.
        val result = render(listOf(item("station")))
        val root = result.views.apply(context, FrameLayout(context))
        assertEquals("更新失敗", root.findViewById<TextView>(R.id.favorite_widget_item_eta).text.toString())
        assertEquals("無法取得班次，請重試", root.findViewById<TextView>(R.id.favorite_widget_item_stop).text.toString())
        assertEquals(View.VISIBLE, root.findViewById<View>(R.id.favorite_widget_empty).visibility)
        assertFalse(result.updateTimestamp)
    }

    @Test
    fun hiddenEntriesDoNotTriggerFailures() {
        val result = render(List(6) { item("route") } + item("station"))
        val root = result.views.apply(context, FrameLayout(context))
        assertEquals(6, root.findViewById<LinearLayout>(R.id.favorite_widget_items_container).childCount)
        assertEquals(View.GONE, root.findViewById<View>(R.id.favorite_widget_empty).visibility)
    }

    private fun render(items: List<FavoriteWidgetItem>): WidgetRenderResult {
        val method = FavoriteGroupWidgetSupport::class.java.getDeclaredMethod(
            "buildContentRemoteViews", Context::class.java, Int::class.javaPrimitiveType,
            String::class.java, List::class.java,
        )
        method.isAccessible = true
        return method.invoke(FavoriteGroupWidgetSupport, context, 1, "Test", items) as WidgetRenderResult
    }

    private fun item(type: String) = FavoriteWidgetItem(
        type = type, provider = "", routeKey = 1, pathId = 0, stopId = 1,
        routeId = null, routeName = "Test route", routeDescription = null,
        stopName = "Test stop", stationId = "test", stationName = "Test station",
        destinationPathId = null, destinationStopId = null, destinationStopName = null,
    )
}
