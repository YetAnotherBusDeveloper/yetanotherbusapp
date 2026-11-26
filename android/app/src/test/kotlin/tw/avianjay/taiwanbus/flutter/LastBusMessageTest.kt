package tw.avianjay.taiwanbus.flutter

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
}
