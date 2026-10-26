package tw.avianjay.taiwanbus.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DepartureNotificationTextTest {
    @Test
    fun preservesElapsedMinutesInFullAndCompactNotifications() {
        assertEquals("未發車 5分", departureNotificationText("未發車\n5分"))
        assertEquals("未發15分", departureNotificationText("未發車 15分", compact = true))
        assertEquals("未確認 逾6分", departureNotificationText("未確認\n逾6分"))
        assertEquals("未確認6分", departureNotificationText("未確認 逾6分", compact = true))
    }

    @Test
    fun preservesNextTimeWithoutConfusingItWithLiveEta() {
        assertEquals("下班 10:20", departureNotificationText("下班表定 10:20（前班動態未確認）", compact = true))
        assertEquals("下班表定 10:20（前班動態未確認）", departureNotificationText("下班表定 10:20（前班動態未確認）"))
        assertNull(departureNotificationText("5分"))
        assertNull(departureNotificationText("進站中"))
        assertNull(departureNotificationText("末班駛離"))
    }
}
