package blake.hash

import blake.hash.TestVectorLoader.objects
import blake.hash.TestVectorLoader.toHex
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory

/**
 * Parity test driven entirely by the shared JSON test-vector files.
 * If a vector exists in the JSON, it is tested here — on both platforms.
 */
class VectorParityTest {

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE2b
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE2b hash vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2b.json")
        return root.getJSONArray("hash").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val digestBytes = v.getInt("digestBytes")
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2b-${digestBytes * 8}")
            DynamicTest.dynamicTest("[$i] $label") {
                val actual = BLAKE2b.hash(input, digestLength = digestBytes)
                assertHex(expected, actual, label)
            }
        }
    }

    @TestFactory
    fun `BLAKE2b keyed vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2b.json")
        val keyed = root.getJSONObject("keyed")
        val key = TestVectorLoader.hexToBytes(keyed.getString("keyHex"))
        return keyed.getJSONArray("vectors").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val digestBytes = v.getInt("digestBytes")
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2b-${digestBytes * 8} keyed")
            DynamicTest.dynamicTest("[$i] $label") {
                val actual = BLAKE2b.hash(input, digestLength = digestBytes, key = key)
                assertHex(expected, actual, label)
            }
        }
    }

    @TestFactory
    fun `BLAKE2b salt+personalization vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2b.json")
        return root.getJSONArray("saltPersonalization").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val digestBytes = v.getInt("digestBytes")
            val salt = v.getString("salt").encodeToByteArray()
            val pers = v.getString("personalization").encodeToByteArray()
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE2b salt+pers") {
                val actual = BLAKE2b.hash(
                    input,
                    digestLength = digestBytes,
                    salt = salt,
                    personalization = pers
                )
                assertHex(expected, actual, "BLAKE2b salt+pers")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE2s
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE2s hash vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2s.json")
        return root.getJSONArray("hash").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val digestBytes = v.getInt("digestBytes")
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2s-${digestBytes * 8}")
            DynamicTest.dynamicTest("[$i] $label") {
                val actual = BLAKE2s.hash(input, digestLength = digestBytes)
                assertHex(expected, actual, label)
            }
        }
    }

    @TestFactory
    fun `BLAKE2s keyed vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2s.json")
        val keyed = root.getJSONObject("keyed")
        val key = TestVectorLoader.hexToBytes(keyed.getString("keyHex"))
        return keyed.getJSONArray("vectors").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val digestBytes = v.getInt("digestBytes")
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2s-${digestBytes * 8} keyed")
            DynamicTest.dynamicTest("[$i] $label") {
                val actual = BLAKE2s.hash(input, digestLength = digestBytes, key = key)
                assertHex(expected, actual, label)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE2bp
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE2bp hash vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2bp.json")
        return root.getJSONArray("hash").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2bp")
            DynamicTest.dynamicTest("[$i] $label") {
                assertHex(expected, BLAKE2bp.hash(input), label)
            }
        }
    }

    @TestFactory
    fun `BLAKE2bp keyed vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2bp.json")
        val keyed = root.getJSONObject("keyed")
        val key = TestVectorLoader.hexToBytes(keyed.getString("keyHex"))
        return keyed.getJSONArray("vectors").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2bp keyed")
            DynamicTest.dynamicTest("[$i] $label") {
                assertHex(expected, BLAKE2bp.hash(input, key = key), label)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE2sp
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE2sp hash vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2sp.json")
        return root.getJSONArray("hash").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2sp")
            DynamicTest.dynamicTest("[$i] $label") {
                assertHex(expected, BLAKE2sp.hash(input), label)
            }
        }
    }

    @TestFactory
    fun `BLAKE2sp keyed vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake2sp.json")
        val keyed = root.getJSONObject("keyed")
        val key = TestVectorLoader.hexToBytes(keyed.getString("keyHex"))
        return keyed.getJSONArray("vectors").objects().mapIndexed { i, v ->
            val input = TestVectorLoader.resolveInput(v)
            val expected = v.getString("expected")
            val label = describeInput(v, "BLAKE2sp keyed")
            DynamicTest.dynamicTest("[$i] $label") {
                assertHex(expected, BLAKE2sp.hash(input, key = key), label)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE3 — hash
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE3 hash named vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        val named = root.getJSONObject("hash").getJSONArray("named")
        return named.objects().mapIndexed { i, v ->
            val input = v.getString("input").encodeToByteArray()
            val expected = v.getString("expected")
            val label = "BLAKE3 hash \"${v.getString("input")}\""
            DynamicTest.dynamicTest("[$i] $label") {
                assertHex(expected, BLAKE3.hash(input), label)
            }
        }
    }

    @TestFactory
    fun `BLAKE3 hash sequential vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        val sequential = root.getJSONObject("hash").getJSONArray("sequential")
        return sequential.objects().mapIndexed { i, v ->
            val len = v.getInt("inputLength")
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE3 hash sequential($len)") {
                assertHex(expected, BLAKE3.hash(TestVectorLoader.blake3Input(len)),
                    "BLAKE3 hash seq($len)")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE3 — keyed hash
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE3 keyed hash vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        val key = TestVectorLoader.hexToBytes(root.getString("keyHex"))
        return root.getJSONArray("keyedHash").objects().mapIndexed { i, v ->
            val len = v.getInt("inputLength")
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE3 keyed($len)") {
                assertHex(expected, BLAKE3.keyedHash(key, TestVectorLoader.blake3Input(len)),
                    "BLAKE3 keyed($len)")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE3 — derive key
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE3 derive key vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        val context = root.getString("deriveKeyContext")
        return root.getJSONArray("deriveKey").objects().mapIndexed { i, v ->
            val len = v.getInt("inputLength")
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE3 deriveKey($len)") {
                assertHex(expected, BLAKE3.deriveKey(context, TestVectorLoader.blake3Input(len)),
                    "BLAKE3 deriveKey($len)")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  BLAKE3 — XOF
    // ════════════════════════════════════════════════════════════════════

    @TestFactory
    fun `BLAKE3 XOF hash vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        return root.getJSONObject("xof").getJSONArray("hash").objects().mapIndexed { i, v ->
            val input = v.getString("input").encodeToByteArray()
            val outputBytes = v.getInt("outputBytes")
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE3 XOF hash(\"${v.getString("input")}\", $outputBytes)") {
                val hasher = BLAKE3.Hasher().update(input)
                val actual = if (outputBytes == 32) hasher.finalize() else hasher.finalizeXof(outputBytes)
                assertHex(expected, actual, "BLAKE3 XOF hash $outputBytes")
            }
        }
    }

    @TestFactory
    fun `BLAKE3 XOF keyed vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        val key = TestVectorLoader.hexToBytes(root.getString("keyHex"))
        return root.getJSONObject("xof").getJSONArray("keyed").objects().mapIndexed { i, v ->
            val input = v.getString("input").encodeToByteArray()
            val outputBytes = v.getInt("outputBytes")
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE3 XOF keyed($outputBytes)") {
                val hasher = BLAKE3.Hasher(key).update(input)
                val actual = if (outputBytes == 32) hasher.finalize() else hasher.finalizeXof(outputBytes)
                assertHex(expected, actual, "BLAKE3 XOF keyed $outputBytes")
            }
        }
    }

    @TestFactory
    fun `BLAKE3 XOF derive key vectors`(): List<DynamicTest> {
        val root = TestVectorLoader.load("blake3.json")
        val context = root.getString("deriveKeyContext")
        return root.getJSONObject("xof").getJSONArray("deriveKey").objects().mapIndexed { i, v ->
            val input = v.getString("input").encodeToByteArray()
            val outputBytes = v.getInt("outputBytes")
            val expected = v.getString("expected")
            DynamicTest.dynamicTest("[$i] BLAKE3 XOF deriveKey($outputBytes)") {
                val hasher = BLAKE3.Hasher.deriveKey(context).update(input)
                val actual = if (outputBytes == 32) hasher.finalize() else hasher.finalizeXof(outputBytes)
                assertHex(expected, actual, "BLAKE3 XOF deriveKey $outputBytes")
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  Helpers
    // ════════════════════════════════════════════════════════════════════

    private fun assertHex(expected: String, actual: ByteArray, context: String) {
        val actualHex = actual.toHex()
        if (expected != actualHex) {
            throw AssertionError("$context\n  expected: $expected\n    actual: $actualHex")
        }
    }

    private fun describeInput(v: org.json.JSONObject, prefix: String): String = when {
        v.has("input") -> {
            val s = v.getString("input")
            if (s.isEmpty()) "$prefix empty" else "$prefix \"$s\""
        }
        v.has("inputHex") -> "$prefix 0x${v.getString("inputHex")}"
        v.has("sequentialLength") -> "$prefix seq(${v.getInt("sequentialLength")})"
        v.has("inputLength") -> "$prefix seq(${v.getInt("inputLength")})"
        else -> "$prefix unknown"
    }
}
