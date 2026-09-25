package tw.avianjay.taiwanbus.flutter

private val lastBusIgnoredCharacters =
    Regex("""[\s\u200B-\u200D\uFEFF，。！？、：；,.!?;:()（）\[\]［］{}【】「」『』<>《》〈〉_\-/]+""")
private val lastBusDeparturePattern =
    Regex("""(?:末班(?:公車|班車|車)?|最後一班(?:公車|車)?)(?:已經|已|己)?(?:駛離|離站|開走|發車|駛過|過站|過了|過)""")

internal fun isLastBusMessage(message: String?): Boolean {
    if (message.isNullOrEmpty()) {
        return false
    }
    val normalized = message.lowercase().replace(lastBusIgnoredCharacters, "")
    return lastBusDeparturePattern.containsMatchIn(normalized)
}
