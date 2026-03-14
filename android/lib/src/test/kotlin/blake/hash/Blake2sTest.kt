package blake.hash

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals

class Blake2sTest {

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun hexToBytes(hex: String): ByteArray =
        hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun sequentialBytes(n: Int): ByteArray =
        ByteArray(n) { (it % 256).toByte() }

    // ── Empty input ─────────────────────────────────────────────────────

    @Test fun `BLAKE2s-128 empty`() {
        assertEquals(
            "64550d6ffe2c0a01a14aba1eade0200c",
            Blake2s.hash(ByteArray(0), digestLength = 16).toHex()
        )
    }

    @Test fun `BLAKE2s-256 empty`() {
        assertEquals(
            "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9",
            Blake2s.hash(ByteArray(0)).toHex()
        )
    }

    // ── "abc" ───────────────────────────────────────────────────────────

    @Test fun `BLAKE2s-128 abc`() {
        assertEquals(
            "aa4938119b1dc7b87cbad0ffd200d0ae",
            Blake2s.hash("abc".toByteArray(), digestLength = 16).toHex()
        )
    }

    @Test fun `BLAKE2s-256 abc`() {
        assertEquals(
            "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982",
            Blake2s.hash("abc".toByteArray()).toHex()
        )
    }

    // ── "The quick brown fox…" ──────────────────────────────────────────

    @Test fun `BLAKE2s-256 quick brown fox`() {
        assertEquals(
            "606beeec743ccbeff6cbcdf5d5302aa855c256c29b88c8ed331ea1a6bf3c8812",
            Blake2s.hash("The quick brown fox jumps over the lazy dog".toByteArray()).toHex()
        )
    }

    // ── Sequential input 32 bytes ───────────────────────────────────────

    @Test fun `BLAKE2s-256 sequential 32 bytes`() {
        assertEquals(
            "05825607d7fdf2d82ef4c3c8c2aea961ad98d60edff7d018983e21204c0d93d1",
            Blake2s.hash(sequentialBytes(32)).toHex()
        )
    }

    // ── Sequential inputs (BLAKE2s-256) ─────────────────────────────────

    @Test fun `BLAKE2s-256 sequential 1 byte`() {
        assertEquals(
            "e34d74dbaf4ff4c6abd871cc220451d2ea2648846c7757fbaac82fe51ad64bea",
            Blake2s.hash(sequentialBytes(1)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 2 bytes`() {
        assertEquals(
            "ddad9ab15dac4549ba42f49d262496bef6c0bae1dd342a8808f8ea267c6e210c",
            Blake2s.hash(sequentialBytes(2)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 4 bytes`() {
        assertEquals(
            "0cc70e00348b86ba2944d0c32038b25c55584f90df2304f55fa332af5fb01e20",
            Blake2s.hash(sequentialBytes(4)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 8 bytes`() {
        assertEquals(
            "c7e887b546623635e93e0495598f1726821996c2377705b93a1f636f872bfa2d",
            Blake2s.hash(sequentialBytes(8)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 16 bytes`() {
        assertEquals(
            "efc04cdc391c7e9119bd38668a534e65fe31036d6a62112e44ebeb11f9c57080",
            Blake2s.hash(sequentialBytes(16)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 64 bytes`() {
        assertEquals(
            "56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e",
            Blake2s.hash(sequentialBytes(64)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 128 bytes`() {
        assertEquals(
            "1fa877de67259d19863a2a34bcc6962a2b25fcbf5cbecd7ede8f1fa36688a796",
            Blake2s.hash(sequentialBytes(128)).toHex()
        )
    }

    @Test fun `BLAKE2s-256 sequential 256 bytes`() {
        assertEquals(
            "5fdeb59f681d975f52c8e69c5502e02a12a3afcc5836ba58f42784c439228781",
            Blake2s.hash(sequentialBytes(256)).toHex()
        )
    }

    // ── BLAKE2s-128 sequential ──────────────────────────────────────────

    @Test fun `BLAKE2s-128 sequential 0 bytes`() {
        assertEquals(
            "64550d6ffe2c0a01a14aba1eade0200c",
            Blake2s.hash(sequentialBytes(0), digestLength = 16).toHex()
        )
    }

    @Test fun `BLAKE2s-128 sequential 1 byte`() {
        assertEquals(
            "9f31f3ec588c6064a8e1f9051aeab90a",
            Blake2s.hash(sequentialBytes(1), digestLength = 16).toHex()
        )
    }

    @Test fun `BLAKE2s-128 sequential 32 bytes`() {
        assertEquals(
            "68b96e07fa73966ccefd87ccad489984",
            Blake2s.hash(sequentialBytes(32), digestLength = 16).toHex()
        )
    }

    @Test fun `BLAKE2s-128 sequential 64 bytes`() {
        assertEquals(
            "dc66ca8f03865801b0ffe06ed8a1a90e",
            Blake2s.hash(sequentialBytes(64), digestLength = 16).toHex()
        )
    }

    // ── Keyed BLAKE2s ───────────────────────────────────────────────────

    @Test fun `BLAKE2s-256 keyed empty`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "48a8997da407876b3d79c0d92325ad3b89cbb754d86ab71aee047ad345fd2c49",
            Blake2s.hash(ByteArray(0), key = key).toHex()
        )
    }

    @Test fun `BLAKE2s-256 keyed abc`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "a281f725754969a702f6fe36fc591b7def866e4b70173ece402fc01c064d6b65",
            Blake2s.hash("abc".toByteArray(), key = key).toHex()
        )
    }

    @Test fun `BLAKE2s-256 keyed sequential 32 bytes`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "c03bc642b20959cbe133a0303e0c1abff3e31ec8e1a328ec8565c36decff5265",
            Blake2s.hash(sequentialBytes(32), key = key).toHex()
        )
    }

    @Test fun `BLAKE2s-128 keyed empty`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "9536f9b267655743dee97b8a670f9f53",
            Blake2s.hash(ByteArray(0), digestLength = 16, key = key).toHex()
        )
    }

    @Test fun `BLAKE2s-128 keyed abc`() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals(
            "61ba5f165c194692e09d12520cc4c74a",
            Blake2s.hash("abc".toByteArray(), digestLength = 16, key = key).toHex()
        )
    }

    // ── Streaming tests ─────────────────────────────────────────────────

    @Test fun `BLAKE2s-256 streaming matches one-shot`() {
        val input = "abc".toByteArray()
        val oneShot = Blake2s.hash(input)
        val streamed = Blake2s.Hasher()
            .update(byteArrayOf(0x61))
            .update(byteArrayOf(0x62))
            .update(byteArrayOf(0x63))
            .finalize()
        assertContentEquals(oneShot, streamed)
    }

    @Test fun `BLAKE2s streaming large input`() {
        val data = sequentialBytes(256)
        val oneShot = Blake2s.hash(data)
        val hasher = Blake2s.Hasher()
        for (b in data) hasher.update(byteArrayOf(b))
        assertContentEquals(oneShot, hasher.finalize())
    }
}
