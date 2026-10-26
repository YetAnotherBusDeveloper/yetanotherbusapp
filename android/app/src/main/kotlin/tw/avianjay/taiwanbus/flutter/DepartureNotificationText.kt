package tw.avianjay.taiwanbus.flutter

private val pendingDeparturePattern = Regex("未發車\\s*(\\d+)\\s*分")
private val unknownDeparturePattern = Regex("未確認\\s*逾(\\d+)\\s*分")
private val nextDeparturePattern = Regex("下班表定\\s*(\\d{2}:\\d{2})")

/** Preserve elapsed origin-departure minutes instead of treating them as ETA. */
internal fun departureNotificationText(message: String, compact: Boolean = false): String? {
    pendingDeparturePattern.find(message)?.let {
        val minutes = it.groupValues[1]
        return if (compact) "未發${minutes}分" else "未發車 ${minutes}分"
    }
    unknownDeparturePattern.find(message)?.let {
        val minutes = it.groupValues[1]
        return if (compact) "未確認${minutes}分" else "未確認 逾${minutes}分"
    }
    nextDeparturePattern.find(message)?.let {
        return if (compact) "下班 ${it.groupValues[1]}" else message.replace('\n', ' ')
    }
    return null
}
