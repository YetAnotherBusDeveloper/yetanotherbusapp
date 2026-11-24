package tw.avianjay.taiwanbus.flutter

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetEtaTextTest {
    @Test
    fun unavailableEstimatesAreNotArriving() {
        listOf<Int?>(null, -1, -60, Int.MIN_VALUE).forEach { seconds ->
            assertEquals("--", widgetEtaText(seconds, null))
        }
    }

    @Test
    fun arrivalBoundaries() {
        assertEquals("進站中", widgetEtaText(0, null))
        assertEquals("即將進站", widgetEtaText(1, null))
        assertEquals("即將進站", widgetEtaText(59, null))
        assertEquals("1分", widgetEtaText(60, null))
        assertEquals("1分", widgetEtaText(119, null))
        assertEquals("2分", widgetEtaText(120, null))
    }

    @Test
    fun meaningfulMessagesTakePrecedence() {
        assertEquals("未發車", widgetEtaText(-1, " 未發車 "))
        assertEquals("末班已過", widgetEtaText(0, "末班已過"))
    }

    @Test
    fun emptyAndJsonNullMessagesDoNotHideEstimates() {
        listOf<String?>(null, "", "  ", "null", " NULL ").forEach { message ->
            assertEquals("2分", widgetEtaText(120, message))
            assertEquals("--", widgetEtaText(-1, message))
        }
    }
}
