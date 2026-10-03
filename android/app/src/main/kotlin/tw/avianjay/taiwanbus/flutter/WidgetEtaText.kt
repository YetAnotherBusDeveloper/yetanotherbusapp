package tw.avianjay.taiwanbus.flutter

/** Keep unavailable estimates distinct from a bus actually entering the stop. */
internal fun widgetEtaText(seconds: Int?, message: String?): String {
    val normalizedMessage = message?.trim().orEmpty()
    if (normalizedMessage.isNotEmpty() && !normalizedMessage.equals("null", ignoreCase = true)) {
        return normalizedMessage
    }
    return when {
        seconds == null || seconds < 0 -> "--"
        seconds == 0 -> "進站中"
        seconds < 60 -> "即將進站"
        else -> "${seconds / 60}分"
    }
}
