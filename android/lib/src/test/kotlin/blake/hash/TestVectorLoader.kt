package blake.hash

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Loads shared JSON test vectors from the test-vectors/ directory.
 * Both platforms read the same files to guarantee parity.
 */
object TestVectorLoader {

    private val vectorsDir: File by lazy {
        val dir = System.getProperty("test.vectors.dir")
            ?: error("System property 'test.vectors.dir' not set — run via Gradle")
        File(dir).also { require(it.isDirectory) { "Test vectors dir not found: $it" } }
    }

    fun load(filename: String): JSONObject =
        JSONObject(vectorsDir.resolve(filename).readText())

    fun loadArray(filename: String): JSONArray =
        JSONArray(vectorsDir.resolve(filename).readText())

    // ---- Input builders ----

    fun hexToBytes(hex: String): ByteArray =
        hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    /** BLAKE2 sequential: bytes([i % 256 for i in range(n)]) */
    fun sequentialBytes(n: Int): ByteArray =
        ByteArray(n) { (it % 256).toByte() }

    /** BLAKE3 sequential: bytes([i % 251 for i in range(n)]) */
    fun blake3Input(n: Int): ByteArray =
        ByteArray(n) { (it % 251).toByte() }

    fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    /**
     * Resolve the input bytes from a JSON vector object.
     * Recognises three mutually-exclusive keys:
     *   "input"            → UTF-8 string
     *   "inputHex"         → hex-encoded bytes
     *   "sequentialLength" → sequential bytes (i % 256)
     *   "inputLength"      → BLAKE3 sequential (i % 251)
     */
    fun resolveInput(vector: JSONObject, blake3: Boolean = false): ByteArray = when {
        vector.has("input")            -> vector.getString("input").encodeToByteArray()
        vector.has("inputHex")         -> hexToBytes(vector.getString("inputHex"))
        vector.has("sequentialLength") -> sequentialBytes(vector.getInt("sequentialLength"))
        vector.has("inputLength")      -> if (blake3) blake3Input(vector.getInt("inputLength"))
                                          else sequentialBytes(vector.getInt("inputLength"))
        else -> error("Vector has no input field: $vector")
    }

    /** Iterate a JSONArray as a sequence of JSONObject. */
    fun JSONArray.objects(): List<JSONObject> =
        (0 until length()).map { getJSONObject(it) }
}
