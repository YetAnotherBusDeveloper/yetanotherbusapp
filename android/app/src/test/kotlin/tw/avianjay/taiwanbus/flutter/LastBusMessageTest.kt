package tw.avianjay.taiwanbus.flutter

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LastBusMessageTest {
    @Test
    fun recognizesNormalizedFinalBusDepartureMessages() {
        listOf(
            "末班駛離",
            "末班已過",
            "末班車已過",
            " 末班車：已經駛離。 ",
            "本日最後一班公車，已離站！",
            "末班車已開走",
        ).forEach { message -> assertTrue(message, isLastBusMessage(message)) }
    }

    @Test
    fun rejectsFutureOrInformationalFinalBusMessages() {
        listOf<String?>(null, "", "末班車 23:00", "末班車尚未駛離", "末班車即將進站", "一般班次已過站")
            .forEach { message -> assertFalse(message, isLastBusMessage(message)) }
    }

    @Test
    fun finalBusLiveStopIsIneligibleForNotification() {
        assertFalse(
            SmartRouteNotificationSupport.shouldNotify(
                SmartLiveStop(sec = 60, msg = "末班車：已過。"),
            ),
        )
    }

    @Test
    fun rankingRetainsLowerCandidatesForEligibilityFallback() {
        val now = Calendar.getInstance()
        val currentHour = now.get(Calendar.HOUR_OF_DAY)
        val profiles = listOf(
            profile(routeKey = 1, hour = currentHour, count = 5),
            profile(routeKey = 1, hour = currentHour, count = 4),
            profile(routeKey = 2, hour = currentHour, count = 3),
        )

        val ranked = SmartRouteNotificationSupport.chooseProfilesForNow(
            profiles = profiles,
            nowMs = now.timeInMillis,
        )

        assertEquals(listOf(1, 2), ranked.map { it.routeKey })
    }

    private fun profile(routeKey: Int, hour: Int, count: Int) = SmartRouteProfile(
        provider = "nwt",
        routeKey = routeKey,
        pathId = 0,
        routeName = routeKey.toString(),
        totalOpens = count,
        lastOpenedAtMs = System.currentTimeMillis(),
        totalSelections = 0,
        lastSelectedAtMs = 0,
        hourlyOpens = mapOf(hour to count),
        hourlySelections = emptyMap(),
    )
}
