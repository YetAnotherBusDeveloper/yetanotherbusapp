package tw.avianjay.taiwanbus.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class TripNotificationTextTest {
    @Test
    fun onboardSubTextOmitsCurrentStopEta() {
        val subText = buildOnboardTripSubText("目前站")

        assertEquals("已上車 · 最近站牌 目前站", subText)
        assertFalse(subText.contains("3 分"))
    }
}
