package blake.hash

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class Blake2spTest {

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun sequentialBytes(n: Int): ByteArray =
        ByteArray(n) { (it % 256).toByte() }

    // ── "abc" ───────────────────────────────────────────────────────────

    @Test fun `BLAKE2sp abc`() {
        assertEquals(
            "70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5",
            Blake2sp.hash("abc".toByteArray()).toHex()
        )
    }

    // ── Keyed ───────────────────────────────────────────────────────────

    @Test fun `BLAKE2sp keyed abc`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "b334a26923410dc586088f365ce36a12bedd33e03c0f4a3808a716dca3a721f0",
            Blake2sp.hash("abc".toByteArray(), key = key).toHex()
        )
    }

    // ── BLAKE2sp ≠ BLAKE2s ──────────────────────────────────────────────

    @Test fun `BLAKE2sp differs from BLAKE2s for same input`() {
        val input = "abc".toByteArray()
        val b2s = Blake2s.hash(input)
        val b2sp = Blake2sp.hash(input)
        assertFalse(b2s.contentEquals(b2sp), "BLAKE2sp must differ from BLAKE2s")
    }

    // ── Streaming test ──────────────────────────────────────────────────

    @Test fun `BLAKE2sp streaming matches one-shot`() {
        val input = "abc".toByteArray()
        val oneShot = Blake2sp.hash(input)
        val streamed = Blake2sp.Hasher()
            .update(byteArrayOf(0x61))
            .update(byteArrayOf(0x62))
            .update(byteArrayOf(0x63))
            .finalize()
        assertContentEquals(oneShot, streamed)
    }

    @Test fun `BLAKE2sp streaming large input`() {
        val data = sequentialBytes(1024)
        val oneShot = Blake2sp.hash(data)
        val hasher = Blake2sp.Hasher()
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
