package io.blake.hash

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class Blake3XofTest {

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    // ---- Hash mode XOF — empty input ----

    @Test fun `hash xof empty 32 bytes`() {
        val out = Blake3.Hasher().finalize()
        assertEquals(
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262",
            out.toHex()
        )
    }

    @Test fun `hash xof empty 64 bytes`() {
        val out = Blake3.Hasher().finalizeXof(64)
        assertEquals(
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262" +
            "e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a",
            out.toHex()
        )
    }

    @Test fun `hash xof empty 128 bytes`() {
        val out = Blake3.Hasher().finalizeXof(128)
        assertEquals(
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262" +
            "e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a" +
            "26f5487789e8f660afe6c99ef9e0c52b92e7393024a80459cf91f476f9ffdbda" +
            "7001c22e159b402631f277ca96f2defdf1078282314e763699a31c5363165421",
            out.toHex()
        )
    }

    // ---- Hash mode XOF — "abc" ----

    @Test fun `hash xof abc 32 bytes`() {
        val out = Blake3.Hasher().update("abc".encodeToByteArray()).finalizeXof(32)
        assertEquals(
            "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85",
            out.toHex()
        )
    }

    @Test fun `hash xof abc 64 bytes`() {
        val out = Blake3.Hasher().update("abc".encodeToByteArray()).finalizeXof(64)
        assertEquals(
            "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85" +
            "1fb250ae7393f5d02813b65d521a0d492d9ba09cf7ce7f4cffd900f23374bf0b",
            out.toHex()
        )
    }

    @Test fun `hash xof abc 128 bytes`() {
        val out = Blake3.Hasher().update("abc".encodeToByteArray()).finalizeXof(128)
        assertEquals(
            "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85" +
            "1fb250ae7393f5d02813b65d521a0d492d9ba09cf7ce7f4cffd900f23374bf0b" +
            "c08a1fb0b38ed276181ccbd9f7b7edbddf9f86404ad7929605f6ffa3fb1ac879" +
            "83105f013384f2f11d38879c985d47003804b905f0c38975e28d36804bb60d8c",
            out.toHex()
        )
    }

    // ---- Keyed XOF — empty input ----

    private val key = ByteArray(32) { it.toByte() }

    @Test fun `keyed xof empty 32 bytes`() {
        val out = Blake3.Hasher(key).finalizeXof(32)
        assertEquals(
            "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f",
            out.toHex()
        )
    }

    @Test fun `keyed xof empty 64 bytes`() {
        val out = Blake3.Hasher(key).finalizeXof(64)
        assertEquals(
            "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f" +
            "097a9b78582396441e22930e5c7c98fd07f896796c81420f14eb9812f0482857",
            out.toHex()
        )
    }

    @Test fun `keyed xof empty 128 bytes`() {
        val out = Blake3.Hasher(key).finalizeXof(128)
        assertEquals(
            "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f" +
            "097a9b78582396441e22930e5c7c98fd07f896796c81420f14eb9812f0482857" +
            "1ebaff5af3de2f693214152e1e3825fa4deeea0414483125b4d46ee75ca0b6e8" +
            "602d0a3cacd8cf0850a291f18b46392f99c74b64e12ae2247592e33668bf6633",
            out.toHex()
        )
    }

    // ---- Derive key XOF — empty input ----

    private val context = "BLAKE3 2019-12-27 16:29:52 test vectors context"

    @Test fun `derive key xof empty 32 bytes`() {
        val out = Blake3.Hasher.deriveKey(context).finalizeXof(32)
        assertEquals(
            "2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d",
            out.toHex()
        )
    }

    @Test fun `derive key xof empty 64 bytes`() {
        val out = Blake3.Hasher.deriveKey(context).finalizeXof(64)
        assertEquals(
            "2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d" +
            "905630c8be290dfcf3e6842f13bddd573c098c3f17361f1f206b8cad9d088aa4",
            out.toHex()
        )
    }

    @Test fun `derive key xof empty 128 bytes`() {
        val out = Blake3.Hasher.deriveKey(context).finalizeXof(128)
        assertEquals(
            "2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d" +
            "905630c8be290dfcf3e6842f13bddd573c098c3f17361f1f206b8cad9d088aa4" +
            "a3f746752c6b0ce6a83b0da81d59649257cdf8eb3e9f7d4998e41021fac119de" +
            "efb896224ac99f860011f73609e6e0e4540f93b273e56547dfd3aa1a035ba668",
            out.toHex()
        )
    }

    // ---- Prefix property: 32 ⊂ 64 ⊂ 128 ----

    @Test fun `hash xof prefix property`() {
        val h = Blake3.Hasher().update("abc".encodeToByteArray())
        val out32 = Blake3.Hasher().update("abc".encodeToByteArray()).finalizeXof(32)
        val out64 = Blake3.Hasher().update("abc".encodeToByteArray()).finalizeXof(64)
        val out128 = Blake3.Hasher().update("abc".encodeToByteArray()).finalizeXof(128)

        assertTrue(out64.toHex().startsWith(out32.toHex()), "64-byte output should start with 32-byte output")
        assertTrue(out128.toHex().startsWith(out64.toHex()), "128-byte output should start with 64-byte output")
    }

    @Test fun `keyed xof prefix property`() {
        val out32 = Blake3.Hasher(key).finalizeXof(32)
        val out64 = Blake3.Hasher(key).finalizeXof(64)
        val out128 = Blake3.Hasher(key).finalizeXof(128)

        assertTrue(out64.toHex().startsWith(out32.toHex()))
        assertTrue(out128.toHex().startsWith(out64.toHex()))
    }

    @Test fun `derive key xof prefix property`() {
        val out32 = Blake3.Hasher.deriveKey(context).finalizeXof(32)
        val out64 = Blake3.Hasher.deriveKey(context).finalizeXof(64)
        val out128 = Blake3.Hasher.deriveKey(context).finalizeXof(128)

        assertTrue(out64.toHex().startsWith(out32.toHex()))
        assertTrue(out128.toHex().startsWith(out64.toHex()))
    }
}
