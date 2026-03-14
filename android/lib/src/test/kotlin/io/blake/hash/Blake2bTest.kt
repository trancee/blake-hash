package io.blake.hash

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class Blake2bTest {

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun hexToBytes(hex: String): ByteArray =
        hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun sequentialBytes(n: Int): ByteArray =
        ByteArray(n) { (it % 256).toByte() }

    // ── Empty input ─────────────────────────────────────────────────────

    @Test fun `BLAKE2b-256 empty`() {
        assertEquals(
            "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8",
            Blake2b.hash(ByteArray(0), digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-384 empty`() {
        assertEquals(
            "b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100",
            Blake2b.hash(ByteArray(0), digestLength = 48).toHex()
        )
    }

    @Test fun `BLAKE2b-512 empty`() {
        assertEquals(
            "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419" +
            "d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce",
            Blake2b.hash(ByteArray(0)).toHex()
        )
    }

    // ── "abc" ───────────────────────────────────────────────────────────

    @Test fun `BLAKE2b-256 abc`() {
        assertEquals(
            "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319",
            Blake2b.hash("abc".toByteArray(), digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-384 abc`() {
        assertEquals(
            "6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4",
            Blake2b.hash("abc".toByteArray(), digestLength = 48).toHex()
        )
    }

    @Test fun `BLAKE2b-512 abc`() {
        assertEquals(
            "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1" +
            "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923",
            Blake2b.hash("abc".toByteArray()).toHex()
        )
    }

    // ── "The quick brown fox…" ──────────────────────────────────────────

    @Test fun `BLAKE2b-256 quick brown fox`() {
        assertEquals(
            "01718cec35cd3d796dd00020e0bfecb473ad23457d063b75eff29c0ffa2e58a9",
            Blake2b.hash("The quick brown fox jumps over the lazy dog".toByteArray(), digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-512 quick brown fox`() {
        assertEquals(
            "a8add4bdddfd93e4877d2746e62817b116364a1fa7bc148d95090bc7333b3673" +
            "f82401cf7aa2e4cb1ecd90296e3f14cb5413f8ed77be73045b13914cdcd6a918",
            Blake2b.hash("The quick brown fox jumps over the lazy dog".toByteArray()).toHex()
        )
    }

    // ── Single-byte inputs (BLAKE2b-512) ────────────────────────────────

    @Test fun `BLAKE2b-512 single byte 0x00`() {
        assertEquals(
            "2fa3f686df876995167e7c2e5d74c4c7b6e48f8068fe0e44208344d480f7904c" +
            "36963e44115fe3eb2a3ac8694c28bcb4f5a0f3276f2e79487d8219057a506e4b",
            Blake2b.hash(byteArrayOf(0x00)).toHex()
        )
    }

    @Test fun `BLAKE2b-512 single byte 0xff`() {
        assertEquals(
            "eb65152dcb7b3371d6399005e2e0fac3e0858c5c51448384666abe437a03ad21" +
            "ed359a62260552978ac341c00c57f1e1ca65af9e46bc57b37764c7cbf5119c44",
            Blake2b.hash(byteArrayOf(0xff.toByte())).toHex()
        )
    }

    // ── Sequential inputs (BLAKE2b-512) ─────────────────────────────────

    @Test fun `BLAKE2b-512 sequential 64 bytes`() {
        assertEquals(
            "2fc6e69fa26a89a5ed269092cb9b2a449a4409a7a44011eecad13d7c4b045660" +
            "2d402fa5844f1a7a758136ce3d5d8d0e8b86921ffff4f692dd95bdc8e5ff0052",
            Blake2b.hash(sequentialBytes(64)).toHex()
        )
    }

    @Test fun `BLAKE2b-512 sequential 128 bytes`() {
        assertEquals(
            "2319e3789c47e2daa5fe807f61bec2a1a6537fa03f19ff32e87eecbfd64b7e0e" +
            "8ccff439ac333b040f19b0c4ddd11a61e24ac1fe0f10a039806c5dcc0da3d115",
            Blake2b.hash(sequentialBytes(128)).toHex()
        )
    }

    @Test fun `BLAKE2b-512 sequential 256 bytes`() {
        assertEquals(
            "1ecc896f34d3f9cac484c73f75f6a5fb58ee6784be41b35f46067b9c65c63a67" +
            "94d3d744112c653f73dd7deb6666204c5a9bfa5b46081fc10fdbe7884fa5cbf8",
            Blake2b.hash(sequentialBytes(256)).toHex()
        )
    }

    // ── Sequential inputs (BLAKE2b-256) ─────────────────────────────────

    @Test fun `BLAKE2b-256 sequential 1 byte`() {
        assertEquals(
            "03170a2e7597b7b7e3d84c05391d139a62b157e78786d8c082f29dcf4c111314",
            Blake2b.hash(sequentialBytes(1), digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-256 sequential 64 bytes`() {
        assertEquals(
            "10d8e6d534b00939843fe9dcc4dae48cdf008f6b8b2b82b156f5404d874887f5",
            Blake2b.hash(sequentialBytes(64), digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-256 sequential 128 bytes`() {
        assertEquals(
            "c3582f71ebb2be66fa5dd750f80baae97554f3b015663c8be377cfcb2488c1d1",
            Blake2b.hash(sequentialBytes(128), digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-256 sequential 256 bytes`() {
        assertEquals(
            "39a7eb9fedc19aabc83425c6755dd90e6f9d0c804964a1f4aaeea3b9fb599835",
            Blake2b.hash(sequentialBytes(256), digestLength = 32).toHex()
        )
    }

    // ── Keyed BLAKE2b ───────────────────────────────────────────────────

    @Test fun `BLAKE2b-512 keyed empty`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "10ebb67700b1868efb4417987acf4690ae9d972fb7a590c2f02871799aaa4786" +
            "b5e996e8f0f4eb981fc214b005f42d2ff4233499391653df7aefcbc13fc51568",
            Blake2b.hash(ByteArray(0), key = key).toHex()
        )
    }

    @Test fun `BLAKE2b-512 keyed abc`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "06bbc3dedf13a31139498655251b7588ccd3bb5aaa071b2d44d8e0a04095579e" +
            "d590fbfdcf941f4370ce5ce623624e7a76d33e7a8109dcda9b57d72f8f8efa51",
            Blake2b.hash("abc".toByteArray(), key = key).toHex()
        )
    }

    @Test fun `BLAKE2b-512 keyed sequential 64 bytes`() {
        val key = ByteArray(64) { it.toByte() }
        assertEquals(
            "65676d800617972fbd87e4b9514e1c67402b7a331096d3bfac22f1abb95374ab" +
            "c942f16e9ab0ead33b87c91968a6e509e119ff07787b3ef483e1dcdccf6e3022",
            Blake2b.hash(sequentialBytes(64), key = key).toHex()
        )
    }

    // ── Salt and personalization ─────────────────────────────────────────

    @Test fun `BLAKE2b-256 with salt and personalization`() {
        val salt = "saltsalt12345678".toByteArray()    // 16 bytes
        val person = "MyApp___v1.0____".toByteArray()   // 16 bytes
        assertEquals(
            "ad0c7e9d37c24d505789156b4467778dd5ee49b3a5c9de53386ada6e7bc74428",
            Blake2b.hash(
                "data".toByteArray(),
                digestLength = 32,
                salt = salt,
                personalization = person
            ).toHex()
        )
    }

    // ── Streaming test ──────────────────────────────────────────────────

    @Test fun `BLAKE2b-512 streaming matches one-shot`() {
        val input = "abc".toByteArray()
        val oneShot = Blake2b.hash(input)
        val streamed = Blake2b.Hasher()
            .update(byteArrayOf(0x61))
            .update(byteArrayOf(0x62))
            .update(byteArrayOf(0x63))
            .finalize()
        assertContentEquals(oneShot, streamed)
    }

    @Test fun `BLAKE2b-256 streaming matches one-shot`() {
        val input = "abc".toByteArray()
        val oneShot = Blake2b.hash(input, digestLength = 32)
        val streamed = Blake2b.Hasher(digestLength = 32)
            .update(byteArrayOf(0x61))
            .update(byteArrayOf(0x62))
            .update(byteArrayOf(0x63))
            .finalize()
        assertContentEquals(oneShot, streamed)
    }

    @Test fun `BLAKE2b streaming large input`() {
        val data = sequentialBytes(256)
        val oneShot = Blake2b.hash(data)
        val hasher = Blake2b.Hasher()
        for (b in data) hasher.update(byteArrayOf(b))
        assertContentEquals(oneShot, hasher.finalize())
    }
}
