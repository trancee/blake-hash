package blake.hash

import kotlin.test.Test
import kotlin.test.assertEquals

class Blake3DeriveKeyTest {

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    private fun blake3Input(n: Int): ByteArray =
        ByteArray(n) { (it % 251).toByte() }

    private val context = "BLAKE3 2019-12-27 16:29:52 test vectors context"

    private fun assertDeriveKey(len: Int, expectedHex: String) {
        assertEquals(expectedHex, Blake3.deriveKey(context, blake3Input(len)).toHex())
    }

    @Test fun `derive key len 0`() =
        assertDeriveKey(0, "2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d")

    @Test fun `derive key len 1`() =
        assertDeriveKey(1, "b3e2e340a117a499c6cf2398a19ee0d29cca2bb7404c73063382693bf66cb06c")

    @Test fun `derive key len 2`() =
        assertDeriveKey(2, "1f166565a7df0098ee65922d7fea425fb18b9943f19d6161e2d17939356168e6")

    @Test fun `derive key len 3`() =
        assertDeriveKey(3, "440aba35cb006b61fc17c0529255de438efc06a8c9ebf3f2ddac3b5a86705797")

    @Test fun `derive key len 4`() =
        assertDeriveKey(4, "f46085c8190d69022369ce1a18880e9b369c135eb93f3c63550d3e7630e91060")

    @Test fun `derive key len 8`() =
        assertDeriveKey(8, "2b166978cef14d9d438046c720519d8b1cad707e199746f1562d0c87fbd32940")

    @Test fun `derive key len 63`() =
        assertDeriveKey(63, "b6451e30b953c206e34644c6803724e9d2725e0893039cfc49584f991f451af3")

    @Test fun `derive key len 64`() =
        assertDeriveKey(64, "a5c4a7053fa86b64746d4bb688d06ad1f02a18fce9afd3e818fefaa7126bf73e")

    @Test fun `derive key len 65`() =
        assertDeriveKey(65, "51fd05c3c1cfbc8ed67d139ad76f5cf8236cd2acd26627a30c104dfd9d3ff8a8")

    @Test fun `derive key len 128`() =
        assertDeriveKey(128, "81720f34452f58a0120a58b6b4608384b5c51d11f39ce97161a0c0e442ca0225")

    @Test fun `derive key len 1023`() =
        assertDeriveKey(1023, "74a16c1c3d44368a86e1ca6df64be6a2f64cce8f09220787450722d85725dea5")

    @Test fun `derive key len 1024`() =
        assertDeriveKey(1024, "7356cd7720d5b66b6d0697eb3177d9f8d73a4a5c5e968896eb6a689684302706")

    @Test fun `derive key len 1025`() =
        assertDeriveKey(1025, "effaa245f065fbf82ac186839a249707c3bddf6d3fdda22d1b95a3c970379bcb")

    @Test fun `derive key len 2048`() =
        assertDeriveKey(2048, "7b2945cb4fef70885cc5d78a87bf6f6207dd901ff239201351ffac04e1088a23")

    @Test fun `derive key len 4096`() =
        assertDeriveKey(4096, "1e0d7f3db8c414c97c6307cbda6cd27ac3b030949da8e23be1a1a924ad2f25b9")
}
