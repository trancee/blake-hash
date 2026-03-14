package blake.hash

import kotlin.test.Test
import kotlin.test.assertEquals

class BLAKE3KeyedTest {

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun blake3Input(n: Int): ByteArray =
        ByteArray(n) { (it % 251).toByte() }

    private val key = ByteArray(32) { it.toByte() }

    private fun assertKeyedHash(len: Int, expectedHex: String) {
        assertEquals(expectedHex, BLAKE3.keyedHash(key, blake3Input(len)).toHex())
    }

    @Test fun `keyed hash len 0`() =
        assertKeyedHash(0, "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f")

    @Test fun `keyed hash len 1`() =
        assertKeyedHash(1, "d08b45c6b127ee94f3f8527a0b82a5f80be1695a0eaec6022e772c0eb95a7e8b")

    @Test fun `keyed hash len 2`() =
        assertKeyedHash(2, "3a771bec5c84aa7ad8c0e214a0598c1d7091113e60595bd2b6db9d4725955e6a")

    @Test fun `keyed hash len 3`() =
        assertKeyedHash(3, "e5326c9674055c012371eb5e26424317732fee320660bdd86d4f719edd7caa29")

    @Test fun `keyed hash len 4`() =
        assertKeyedHash(4, "ecc370c5be25c5de9f633943eeed5ebb22df19f35dac8a37389ef618798a9736")

    @Test fun `keyed hash len 8`() =
        assertKeyedHash(8, "8493f7c4b5f5373035a1316f0ec81d498942ffd7ca4d50c9d43140ca8ec376a6")

    @Test fun `keyed hash len 63`() =
        assertKeyedHash(63, "e471df92f6f7dee100138af7da29695906b0dc34ccde2142a730dd4ebcbc09cc")

    @Test fun `keyed hash len 64`() =
        assertKeyedHash(64, "cfaf838ff320e0d87301dcba02b1a4bb397d65119f57403df2817a51d4025f9b")

    @Test fun `keyed hash len 65`() =
        assertKeyedHash(65, "d8a45528bfa93a0d9b7bf4c840b68f64af0b9ad3d0bbd6c1421c2a4cf1cdf3b4")

    @Test fun `keyed hash len 128`() =
        assertKeyedHash(128, "fe43a847dfccdfa5f070664fb8b51d7b906341ff81ac4adafbf6a3ffac564def")

    @Test fun `keyed hash len 1023`() =
        assertKeyedHash(1023, "da1f18069871512af22af9f13dc005800dfd52c55f42753b5ae718086fe2ee44")

    @Test fun `keyed hash len 1024`() =
        assertKeyedHash(1024, "f45a9249a627fdf1fcf13c0e6376f6a9a9b2056d6e1b5693a4b119a3453665f9")

    @Test fun `keyed hash len 1025`() =
        assertKeyedHash(1025, "82223147a9b804a0c3f9a921b8d8aee250d1a51bb76be72152e6d5e8f27349b3")

    @Test fun `keyed hash len 2048`() =
        assertKeyedHash(2048, "636bfa717d4f9fc3e59da9b2e5cce6a2b78eb70469c0fce49da38b5419892423")

    @Test fun `keyed hash len 4096`() =
        assertKeyedHash(4096, "e8c6e859e0480c4b062457defd04d2f4303b6cc280a0fe080ec5c4346a171937")
}
