package io.blake.hash

import kotlin.test.Test
import kotlin.test.assertEquals

class CrossAlgorithmTest {

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private val abc = "abc".encodeToByteArray()

    // ---- Unkeyed hashes of "abc" ----

    @Test fun `BLAKE2b-256 abc`() {
        assertEquals(
            "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319",
            Blake2b.hash(abc, digestLength = 32).toHex()
        )
    }

    @Test fun `BLAKE2b-512 abc`() {
        assertEquals(
            "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1" +
            "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923",
            Blake2b.hash(abc).toHex()
        )
    }

    @Test fun `BLAKE2s-256 abc`() {
        assertEquals(
            "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982",
            Blake2s.hash(abc).toHex()
        )
    }

    @Test fun `BLAKE2s-128 abc`() {
        assertEquals(
            "aa4938119b1dc7b87cbad0ffd200d0ae",
            Blake2s.hash(abc, digestLength = 16).toHex()
        )
    }

    @Test fun `BLAKE3 abc`() {
        assertEquals(
            "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85",
            Blake3.hash(abc).toHex()
        )
    }

    @Test fun `BLAKE2bp abc`() {
        assertEquals(
            "b91a6b66ae87526c400b0a8b53774dc65284ad8f6575f8148ff93dff943a6ecd" +
            "8362130f22d6dae633aa0f91df4ac89aaff31d0f1b923c898e82025dedbdad6e",
            Blake2bp.hash(abc).toHex()
        )
    }

    @Test fun `BLAKE2sp abc`() {
        assertEquals(
            "70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5",
            Blake2sp.hash(abc).toHex()
        )
    }

    // ---- Keyed hashes of "abc" ----

    @Test fun `BLAKE2b keyed abc`() {
        val key = ByteArray(64) { it.toByte() } // 0x00..0x3f
        assertEquals(
            "06bbc3dedf13a31139498655251b7588ccd3bb5aaa071b2d44d8e0a04095579e" +
            "d590fbfdcf941f4370ce5ce623624e7a76d33e7a8109dcda9b57d72f8f8efa51",
            Blake2b.hash(abc, key = key).toHex()
        )
    }

    @Test fun `BLAKE2s keyed abc`() {
        val key = ByteArray(32) { it.toByte() } // 0x00..0x1f
        assertEquals(
            "a281f725754969a702f6fe36fc591b7def866e4b70173ece402fc01c064d6b65",
            Blake2s.hash(abc, key = key).toHex()
        )
    }

    @Test fun `BLAKE3 keyed_hash abc`() {
        val key = ByteArray(32) { it.toByte() } // 0x00..0x1f
        assertEquals(
            "6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532",
            Blake3.keyedHash(key, abc).toHex()
        )
    }
}
