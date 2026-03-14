package blake.hash

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class Blake2bpTest {

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun sequentialBytes(n: Int): ByteArray =
        ByteArray(n) { (it % 256).toByte() }

    // ── Empty input (unkeyed) ───────────────────────────────────────────

    @Test fun `BLAKE2bp empty`() {
        assertEquals(
            "b5ef811a8038f70b628fa8b294daae7492b1ebe343a80eaabbf1f6ae664dd67b" +
            "9d90b0120791eab81dc96985f28849f6a305186a85501b405114bfa678df9380",
            Blake2bp.hash(ByteArray(0)).toHex()
        )
    }

    // ── "abc" ───────────────────────────────────────────────────────────

    @Test fun `BLAKE2bp abc`() {
        assertEquals(
            "b91a6b66ae87526c400b0a8b53774dc65284ad8f6575f8148ff93dff943a6ecd" +
            "8362130f22d6dae633aa0f91df4ac89aaff31d0f1b923c898e82025dedbdad6e",
            Blake2bp.hash("abc".toByteArray()).toHex()
        )
    }

    // ── Keyed ───────────────────────────────────────────────────────────

    @Test fun `BLAKE2bp keyed abc`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "8943f40e65e41fdbbe79b701b26279125bbe120379dd77d74fdb5faf662ed6a3" +
            "974aa1dce99a3349a492159fa0ded8245a5167c11886170a3af12888448fa8b2",
            Blake2bp.hash("abc".toByteArray(), key = key).toHex()
        )
    }

    // ── BLAKE2bp ≠ BLAKE2b ──────────────────────────────────────────────

    @Test fun `BLAKE2bp differs from BLAKE2b for same input`() {
        val input = "abc".toByteArray()
        val b2b = Blake2b.hash(input)
        val b2bp = Blake2bp.hash(input)
        assertFalse(b2b.contentEquals(b2bp), "BLAKE2bp must differ from BLAKE2b")
    }

    // ── Streaming test ──────────────────────────────────────────────────

    @Test fun `BLAKE2bp streaming matches one-shot`() {
        val input = "abc".toByteArray()
        val oneShot = Blake2bp.hash(input)
        val streamed = Blake2bp.Hasher()
            .update(byteArrayOf(0x61))
            .update(byteArrayOf(0x62))
            .update(byteArrayOf(0x63))
            .finalize()
        assertContentEquals(oneShot, streamed)
    }

    @Test fun `BLAKE2bp streaming large input`() {
        val data = sequentialBytes(1024)
        val oneShot = Blake2bp.hash(data)
        val hasher = Blake2bp.Hasher()
        // Feed in varying chunk sizes
        var offset = 0
        val chunks = intArrayOf(1, 7, 13, 64, 128, 256, 512, 43)
        var ci = 0
        while (offset < data.size) {
            val len = minOf(chunks[ci % chunks.size], data.size - offset)
            hasher.update(data.copyOfRange(offset, offset + len))
            offset += len
            ci++
        }
        assertContentEquals(oneShot, hasher.finalize())
    }
}
