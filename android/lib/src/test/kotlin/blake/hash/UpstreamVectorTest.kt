package blake.hash

import blake.hash.TestVectorLoader.objects
import blake.hash.TestVectorLoader.toHex
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory

/**
 * Tests against the official upstream Known Answer Test (KAT) vectors:
 *
 * - BLAKE2: https://github.com/BLAKE2/BLAKE2/blob/master/testvectors/blake2-kat.json
 *   256 unkeyed + 256 keyed vectors per algorithm (blake2b, blake2s, blake2bp, blake2sp).
 *   Input is sequential bytes: input[i] = i for i in 0..<N, where N = 0..255.
 *
 * - BLAKE3: https://github.com/BLAKE3-team/BLAKE3/blob/master/test_vectors/test_vectors.json
 *   35 cases covering hash, keyed_hash, and derive_key modes.
 *   Input is sequential bytes: input[i] = i % 251.
 *   Extended outputs are provided; we verify the first 32 bytes match default-length output.
 */
class UpstreamVectorTest {

    companion object {
        /** XOF output size used for upstream extended-output tests (bytes). */
        private const val XOF_BYTES = 64
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE2 — upstream KAT (blake2-kat.json)
    // ════════════════════════════════════════════════════════════════════

    private fun blake2Kat(algorithm: String) =
        TestVectorLoader.loadArray("upstream/blake2-kat.json").objects()
            .filter { it.getString("hash") == algorithm }

    @TestFactory
    fun `BLAKE2b upstream unkeyed`(): List<DynamicTest> =
        blake2Kat("blake2b").filter { it.getString("key").isEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2b unkeyed len=${input.size}") {
                assertHex(expected, Blake2b.hash(input))
            }
        }

    @TestFactory
    fun `BLAKE2b upstream keyed`(): List<DynamicTest> =
        blake2Kat("blake2b").filter { it.getString("key").isNotEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val key = TestVectorLoader.hexToBytes(v.getString("key"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2b keyed len=${input.size}") {
                assertHex(expected, Blake2b.hash(input, key = key))
            }
        }

    @TestFactory
    fun `BLAKE2s upstream unkeyed`(): List<DynamicTest> =
        blake2Kat("blake2s").filter { it.getString("key").isEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2s unkeyed len=${input.size}") {
                assertHex(expected, Blake2s.hash(input))
            }
        }

    @TestFactory
    fun `BLAKE2s upstream keyed`(): List<DynamicTest> =
        blake2Kat("blake2s").filter { it.getString("key").isNotEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val key = TestVectorLoader.hexToBytes(v.getString("key"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2s keyed len=${input.size}") {
                assertHex(expected, Blake2s.hash(input, key = key))
            }
        }

    @TestFactory
    fun `BLAKE2bp upstream unkeyed`(): List<DynamicTest> =
        blake2Kat("blake2bp").filter { it.getString("key").isEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2bp unkeyed len=${input.size}") {
                assertHex(expected, Blake2bp.hash(input))
            }
        }

    @TestFactory
    fun `BLAKE2bp upstream keyed`(): List<DynamicTest> =
        blake2Kat("blake2bp").filter { it.getString("key").isNotEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val key = TestVectorLoader.hexToBytes(v.getString("key"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2bp keyed len=${input.size}") {
                assertHex(expected, Blake2bp.hash(input, key = key))
            }
        }

    @TestFactory
    fun `BLAKE2sp upstream unkeyed`(): List<DynamicTest> =
        blake2Kat("blake2sp").filter { it.getString("key").isEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2sp unkeyed len=${input.size}") {
                assertHex(expected, Blake2sp.hash(input))
            }
        }

    @TestFactory
    fun `BLAKE2sp upstream keyed`(): List<DynamicTest> =
        blake2Kat("blake2sp").filter { it.getString("key").isNotEmpty() }.mapIndexed { i, v ->
            val input = TestVectorLoader.hexToBytes(v.getString("in"))
            val key = TestVectorLoader.hexToBytes(v.getString("key"))
            val expected = v.getString("out")
            DynamicTest.dynamicTest("[$i] blake2sp keyed len=${input.size}") {
                assertHex(expected, Blake2sp.hash(input, key = key))
            }
        }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE3 — upstream official vectors (blake3-official.json)
    // ════════════════════════════════════════════════════════════════════

    private val blake3Root by lazy { TestVectorLoader.load("upstream/blake3-official.json") }
    private val blake3Key by lazy { blake3Root.getString("key").encodeToByteArray() }
    private val blake3Context by lazy { blake3Root.getString("context_string") }
    private val blake3Cases by lazy { blake3Root.getJSONArray("cases").objects() }

    @TestFactory
    fun `BLAKE3 upstream hash`(): List<DynamicTest> =
        blake3Cases.mapIndexed { i, v ->
            val len = v.getInt("input_len")
            val extendedHex = v.getString("hash")
            val expected32 = extendedHex.take(64)
            DynamicTest.dynamicTest("[$i] blake3 hash len=$len") {
                assertHex(expected32, Blake3.hash(TestVectorLoader.blake3Input(len)))
            }
        }

    @TestFactory
    fun `BLAKE3 upstream keyed hash`(): List<DynamicTest> =
        blake3Cases.mapIndexed { i, v ->
            val len = v.getInt("input_len")
            val extendedHex = v.getString("keyed_hash")
            val expected32 = extendedHex.take(64)
            DynamicTest.dynamicTest("[$i] blake3 keyed_hash len=$len") {
                assertHex(expected32, Blake3.keyedHash(blake3Key, TestVectorLoader.blake3Input(len)))
            }
        }

    @TestFactory
    fun `BLAKE3 upstream derive key`(): List<DynamicTest> =
        blake3Cases.mapIndexed { i, v ->
            val len = v.getInt("input_len")
            val extendedHex = v.getString("derive_key")
            val expected32 = extendedHex.take(64)
            DynamicTest.dynamicTest("[$i] blake3 derive_key len=$len") {
                assertHex(expected32, Blake3.deriveKey(blake3Context, TestVectorLoader.blake3Input(len)))
            }
        }

    @TestFactory
    fun `BLAKE3 upstream XOF hash`(): List<DynamicTest> =
        blake3Cases.mapIndexed { i, v ->
            val len = v.getInt("input_len")
            val extendedHex = v.getString("hash")
            DynamicTest.dynamicTest("[$i] blake3 XOF hash len=$len out=$XOF_BYTES") {
                val hasher = Blake3.Hasher().update(TestVectorLoader.blake3Input(len))
                val actual = hasher.finalizeXof(XOF_BYTES)
                assertHex(extendedHex.take(XOF_BYTES * 2), actual)
            }
        }

    @TestFactory
    fun `BLAKE3 upstream XOF keyed hash`(): List<DynamicTest> =
        blake3Cases.mapIndexed { i, v ->
            val len = v.getInt("input_len")
            val extendedHex = v.getString("keyed_hash")
            DynamicTest.dynamicTest("[$i] blake3 XOF keyed_hash len=$len out=$XOF_BYTES") {
                val hasher = Blake3.Hasher(blake3Key).update(TestVectorLoader.blake3Input(len))
                val actual = hasher.finalizeXof(XOF_BYTES)
                assertHex(extendedHex.take(XOF_BYTES * 2), actual)
            }
        }

    @TestFactory
    fun `BLAKE3 upstream XOF derive key`(): List<DynamicTest> =
        blake3Cases.mapIndexed { i, v ->
            val len = v.getInt("input_len")
            val extendedHex = v.getString("derive_key")
            DynamicTest.dynamicTest("[$i] blake3 XOF derive_key len=$len out=$XOF_BYTES") {
                val hasher = Blake3.Hasher.deriveKey(blake3Context).update(TestVectorLoader.blake3Input(len))
                val actual = hasher.finalizeXof(XOF_BYTES)
                assertHex(extendedHex.take(XOF_BYTES * 2), actual)
            }
        }

    // ════════════════════════════════════════════════════════════════════
    //  Helpers
    // ════════════════════════════════════════════════════════════════════

    private fun assertHex(expected: String, actual: ByteArray) {
        val actualHex = actual.toHex()
        if (expected != actualHex) {
            throw AssertionError("Upstream vector mismatch\n  expected: $expected\n    actual: $actualHex")
        }
    }
}
