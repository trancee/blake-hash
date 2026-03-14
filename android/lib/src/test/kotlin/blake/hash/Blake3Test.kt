package blake.hash

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertContentEquals

class BLAKE3Test {

    // ---- Helpers ----

    private fun hexToBytes(hex: String): ByteArray =
        hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun blake3Input(n: Int): ByteArray =
        ByteArray(n) { (it % 251).toByte() }

    // ---- Named-input tests ----

    @Test fun `hash empty`() {
        assertEquals(
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262",
            BLAKE3.hash(ByteArray(0)).toHex()
        )
    }

    @Test fun `hash abc`() {
        assertEquals(
            "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85",
            BLAKE3.hash("abc".encodeToByteArray()).toHex()
        )
    }

    @Test fun `hash IETF`() {
        assertEquals(
            "83a2de1ee6f4e6ab686889248f4ec0cf4cc5709446a682ffd1cbb4d6165181e2",
            BLAKE3.hash("IETF".encodeToByteArray()).toHex()
        )
    }

    @Test fun `hash quick brown fox`() {
        assertEquals(
            "2f1514181aadccd913abd94cfa592701a5686ab23f8df1dff1b74710febc6d4a",
            BLAKE3.hash("The quick brown fox jumps over the lazy dog".encodeToByteArray()).toHex()
        )
    }

    // ---- Sequential-input (i % 251) tests ----

    @Test fun `hash sequential len 0`() =
        assertHash(0, "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262")

    @Test fun `hash sequential len 1`() =
        assertHash(1, "2d3adedff11b61f14c886e35afa036736dcd87a74d27b5c1510225d0f592e213")

    @Test fun `hash sequential len 2`() =
        assertHash(2, "7b7015bb92cf0b318037702a6cdd81dee41224f734684c2c122cd6359cb1ee63")

    @Test fun `hash sequential len 3`() =
        assertHash(3, "e1be4d7a8ab5560aa4199eea339849ba8e293d55ca0a81006726d184519e647f")

    @Test fun `hash sequential len 4`() =
        assertHash(4, "f30f5ab28fe047904037f77b6da4fea1e27241c5d132638d8bedce9d40494f32")

    @Test fun `hash sequential len 8`() =
        assertHash(8, "2351207d04fc16ade43ccab08600939c7c1fa70a5c0aaca76063d04c3228eaeb")

    @Test fun `hash sequential len 63`() =
        assertHash(63, "e9bc37a594daad83be9470df7f7b3798297c3d834ce80ba85d6e207627b7db7b")

    @Test fun `hash sequential len 64`() =
        assertHash(64, "4eed7141ea4a5cd4b788606bd23f46e212af9cacebacdc7d1f4c6dc7f2511b98")

    @Test fun `hash sequential len 65`() =
        assertHash(65, "de1e5fa0be70df6d2be8fffd0e99ceaa8eb6e8c93a63f2d8d1c30ecb6b263dee")

    @Test fun `hash sequential len 128`() =
        assertHash(128, "f17e570564b26578c33bb7f44643f539624b05df1a76c81f30acd548c44b45ef")

    @Test fun `hash sequential len 1023`() =
        assertHash(1023, "10108970eeda3eb932baac1428c7a2163b0e924c9a9e25b35bba72b28f70bd11")

    @Test fun `hash sequential len 1024`() =
        assertHash(1024, "42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7")

    @Test fun `hash sequential len 1025`() =
        assertHash(1025, "d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444")

    @Test fun `hash sequential len 2048`() =
        assertHash(2048, "e776b6028c7cd22a4d0ba182a8bf62205d2ef576467e838ed6f2529b85fba24a")

    @Test fun `hash sequential len 4096`() =
        assertHash(4096, "015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969")

    @Test fun `hash sequential len 8192`() =
        assertHash(8192, "aae792484c8efe4f19e2ca7d371d8c467ffb10748d8a5a1ae579948f718a2a63")

    @Test fun `hash sequential len 16384`() =
        assertHash(16384, "f875d6646de28985646f34ee13be9a576fd515f76b5b0a26bb324735041ddde4")

    @Test fun `hash sequential len 65536`() =
        assertHash(65536, "68d647e619a930e7b1082f74f334b0c65a315725569bdc123f0ee11881717bfe")

    @Test fun `hash sequential len 131072`() =
        assertHash(131072, "306baba93b1a393cbd35172837c98b0f59a41f64e1b2682ae102d8b2534b9e1c")

    // ---- Streaming consistency ----

    @Test fun `streaming matches one-shot for abc`() {
        val expected = BLAKE3.hash("abc".encodeToByteArray())
        val hasher = BLAKE3.Hasher()
        for (b in "abc".encodeToByteArray()) {
            hasher.update(byteArrayOf(b))
        }
        assertContentEquals(expected, hasher.finalize())
    }

    // ---- Helper ----

    private fun assertHash(len: Int, expectedHex: String) {
        assertEquals(expectedHex, BLAKE3.hash(blake3Input(len)).toHex())
    }
}
