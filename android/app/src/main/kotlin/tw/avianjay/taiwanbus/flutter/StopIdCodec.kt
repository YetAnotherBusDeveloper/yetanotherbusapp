package tw.avianjay.taiwanbus.flutter

/**
 * Folds a stop id from any source into the single positive `Int` the app keys
 * stops by.
 *
 * Stop ids are 64-bit in the feeds (高雄's look like `100100128221`) but every
 * stop map in the app is keyed by `Int`, and the two sides of that key used to
 * disagree: the session payload was read with `optInt`, which wraps to the low
 * 32 bits, while the live feed fell back to hashing the id as text. The two
 * values can never be equal, so a 高雄 stop's live ETA was unreachable — and
 * ids that wrapped negative were dropped by the `> 0` filters as well.
 *
 * Both sides call this now. Values that already fit in 31 bits pass through
 * untouched, so 台中 and 雙北 ids are unaffected, and the fold is idempotent,
 * so a value that has been through it stays put. It never returns a negative
 * number, which is what makes the `> 0` filters safe. Real ids do not collide
 * under it, and the hash fallback still covers the non-numeric ids some
 * providers use (`101-11009`).
 *
 * Returns 0 for a missing or blank id so callers can keep filtering on `> 0`.
 */
internal fun foldStopId(raw: Any?): Int {
    val text = when (raw) {
        // JSON numbers can arrive as any boxed type; going through Long keeps
        // an integral id from being mangled into exponent notation.
        is Number -> raw.toLong().toString()
        else -> raw?.toString()?.trim().orEmpty()
    }
    // org.json hands back JSONObject.NULL rather than null for absent fields,
    // and hashing its text would invent an id out of nothing.
    if (text.isEmpty() || text.equals("null", ignoreCase = true)) {
        return 0
    }
    text.toLongOrNull()?.let { value ->
        if (value >= 0L) {
            return (value and 0x7FFFFFFFL).toInt()
        }
    }
    var hash = 17
    for (char in text) {
        hash = (hash * 31 + char.code) and 0x7fffffff
    }
    return hash
}

/**
 * The stop id as Flutter holds it, for launch payloads (widget taps, notification
 * taps, pinned shortcuts).
 *
 * Dart keys stops by the id it read from the feed: numeric ids stay 64-bit
 * (高雄's `100100128221` would not fit in an `Int`), non-numeric ones hash. The
 * native fold is only for joining the live feeds and must not be sent to Dart —
 * a folded id names no stop the Flutter side knows, so the tap would silently
 * open the wrong stop or none at all. This returns the value Dart itself would
 * have computed for the same raw id.
 */
internal fun launchStopId(raw: Any?): Long {
    val text = when (raw) {
        is Number -> raw.toLong().toString()
        else -> raw?.toString()?.trim().orEmpty()
    }
    if (text.isEmpty() || text.equals("null", ignoreCase = true)) {
        return 0L
    }
    text.toLongOrNull()?.let { return it }
    // Non-numeric ids hash on both sides, and both hashes start at 17, so the
    // folded value already is what Dart computed.
    return foldStopId(raw).toLong()
}
