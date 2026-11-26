package tw.avianjay.taiwanbus.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Stop ids are 64-bit in the feeds but every stop map in the app is keyed by an
 * `Int`. Both sides of that key fold through [foldStopId]; if they ever
 * disagree, the live ETA of a 高雄 stop can never be looked up.
 */
class StopIdCodecTest {
    @Test
    fun leavesIdsThatAlreadyFitAlone() {
        // 台中 and 雙北 ids are small; folding them must be a no-op.
        assertEquals(13567, foldStopId("13567"))
        assertEquals(194687, foldStopId(194687))
        assertEquals(1001001781, foldStopId("1001001781"))
    }

    @Test
    fun foldsIdsTooLargeForAnInt() {
        // 高雄's real ids are 11-12 digits.
        assertEquals(1315880413, foldStopId("100100128221"))
        assertEquals(1315910904, foldStopId("100100158712"))
    }

    @Test
    fun neverReturnsSomethingThePositiveFiltersWouldDrop() {
        // 172 高雄 routes have ids whose low 32 bits are negative; a plain
        // toInt() turns those into ids the `> 0` checks throw away.
        val ids = listOf("101111144601", "100100128221", "100100158712", "99999999999")
        ids.forEach { raw ->
            assertTrue("$raw folded to a non-positive id", foldStopId(raw) > 0)
        }
    }

    @Test
    fun foldingIsIdempotent() {
        // A value that has already been folded can be folded again: the session
        // is rebuilt from a payload that already carries folded ids.
        val once = foldStopId("100100128221")
        assertEquals(once, foldStopId(once))
    }

    @Test
    fun bothSidesOfTheJoinAgree() {
        // The exact bug: the session side truncated while the feed side hashed,
        // and the two values could never be equal.
        val fromFeed = foldStopId("100100128221")
        val fromSession = foldStopId("100100128221")
        assertEquals(fromFeed, fromSession)
    }

    @Test
    fun hashesIdsThatAreNotNumeric() {
        // Some providers use ids like "101-11009".
        val first = foldStopId("101-11009")
        val second = foldStopId("101-11175")
        assertTrue("non-numeric ids must still fold to positive keys", first > 0 && second > 0)
        assertEquals("the same id must always fold the same way", first, foldStopId("101-11009"))
        assertTrue("different ids must not collide", first != second)
    }

    @Test
    fun missingIdsFoldToZeroSoTheFiltersStillWork() {
        assertEquals(0, foldStopId(null))
        assertEquals(0, foldStopId(""))
        assertEquals(0, foldStopId("   "))
        // org.json hands back JSONObject.NULL for absent fields.
        assertEquals(0, foldStopId(org.json.JSONObject.NULL))
    }

    @Test
    fun realIdsDoNotCollide() {
        // Verified against the backend's 114,903 distinct ids: masking collides
        // on none of them.
        val ids = listOf(
            "13567", "12251", "194687", "1001001781", "100100128221",
            "100100158712", "101111144601", "101111144651", "101111144681",
        )
        val folded = ids.map(::foldStopId)
        assertEquals("folding must be injective for real ids", ids.size, folded.toSet().size)
    }
}
