package blake.hash

import blake.hash.internal.*

/**
 * BLAKE2s cryptographic hash function.
 *
 * 32-bit variant with 64-byte blocks and up to 32-byte digests.
 */
public class Blake2s private constructor() {

    public companion object {
        private const val BLOCK_SIZE = 64
        private const val MAX_DIGEST = 32
        private const val MAX_KEY = 32

        /**
         * One-shot hash: returns the BLAKE2s digest of [input].
         */
        public fun hash(
            input: ByteArray,
            digestLength: Int = MAX_DIGEST,
            key: ByteArray = ByteArray(0),
            salt: ByteArray = ByteArray(0),
            personalization: ByteArray = ByteArray(0)
        ): ByteArray {
            val hasher = Hasher(digestLength, key, salt, personalization)
            hasher.update(input)
            return hasher.finalize()
        }
    }

    /**
     * Incremental BLAKE2s hasher for streaming data.
     */
    public class Hasher @JvmOverloads public constructor(
        digestLength: Int = MAX_DIGEST,
        key: ByteArray = ByteArray(0),
        salt: ByteArray = ByteArray(0),
        personalization: ByteArray = ByteArray(0)
    ) {
        private val engine = Blake2sEngine(
            digestLength = digestLength,
            key = key,
            salt = salt,
            personalization = personalization
        )

        public fun update(input: ByteArray): Hasher {
            engine.update(input, 0, input.size)
            return this
        }

        public fun update(input: ByteArray, offset: Int, length: Int): Hasher {
            engine.update(input, offset, length)
            return this
        }

        public fun finalize(): ByteArray = engine.finalize()
    }
}

// ---------------------------------------------------------------------------
// Internal engine – also used by Blake2sp
// ---------------------------------------------------------------------------

internal class Blake2sEngine(
    private val digestLength: Int,
    key: ByteArray = ByteArray(0),
    salt: ByteArray = ByteArray(0),
    personalization: ByteArray = ByteArray(0),
    fanout: Int = 1,
    depth: Int = 1,
    leafLength: Int = 0,
    nodeOffset: Long = 0,
    nodeDepth: Int = 0,
    innerLength: Int = 0,
    paramKeyLength: Int = key.size
) {
    companion object {
        const val BLOCK_SIZE = 64
        const val MAX_DIGEST = 32
        private const val ROUNDS = 10

        val IV = intArrayOf(
            0x6A09E667, 0xBB67AE85.toInt(),
            0x3C6EF372, 0xA54FF53A.toInt(),
            0x510E527F, 0x9B05688C.toInt(),
            0x1F83D9AB, 0x5BE0CD19
        )
    }

    private val h = IntArray(8)
    private var t0: Int = 0
    private var t1: Int = 0
    private val buffer = ByteArray(BLOCK_SIZE)
    private var bufferOffset = 0
    internal var lastNode: Boolean = false

    // Pre-allocated message word array — avoids per-compress allocation
    private val m = IntArray(16)

    init {
        require(digestLength in 1..MAX_DIGEST) { "digestLength must be 1..32" }
        require(key.size <= MAX_DIGEST) { "key must be 0..32 bytes" }
        require(salt.size <= 8) { "salt must be 0..8 bytes" }
        require(personalization.size <= 8) { "personalization must be 0..8 bytes" }

        // Build the 32-byte parameter block
        // Byte 0: digest length, 1: key length, 2: fanout, 3: depth
        // Bytes 4-7: leaf length
        // Bytes 8-13: node offset (6 bytes, little-endian)
        // Byte 14: node depth, Byte 15: inner length
        // Bytes 16-23: salt (8 bytes)
        // Bytes 24-31: personalization (8 bytes)
        val p = ByteArray(32)
        p[0] = digestLength.toByte()
        p[1] = paramKeyLength.toByte()
        p[2] = fanout.toByte()
        p[3] = depth.toByte()
        storeInt(leafLength, p, 4)
        // node offset: 6 bytes little-endian at bytes 8-13
        p[8]  = (nodeOffset).toByte()
        p[9]  = (nodeOffset ushr 8).toByte()
        p[10] = (nodeOffset ushr 16).toByte()
        p[11] = (nodeOffset ushr 24).toByte()
        p[12] = (nodeOffset ushr 32).toByte()
        p[13] = (nodeOffset ushr 40).toByte()
        p[14] = nodeDepth.toByte()
        p[15] = innerLength.toByte()
        if (salt.isNotEmpty()) salt.copyInto(p, 16)
        if (personalization.isNotEmpty()) personalization.copyInto(p, 24)

        // h = IV xor paramBlock (8 x 32-bit words)
        for (i in 0..7) {
            h[i] = IV[i] xor loadInt(p, i * 4)
        }

        // If keyed, pad key to a full block and buffer it
        if (key.isNotEmpty()) {
            key.copyInto(buffer)
            bufferOffset = BLOCK_SIZE
        }
    }

    fun update(input: ByteArray, offset: Int, length: Int): Blake2sEngine {
        var pos = offset
        var remaining = length
        if (remaining == 0) return this

        if (bufferOffset > 0 && remaining > 0) {
            val space = BLOCK_SIZE - bufferOffset
            val n = minOf(space, remaining)
            input.copyInto(buffer, bufferOffset, pos, pos + n)
            bufferOffset += n
            pos += n
            remaining -= n
        }

        if (bufferOffset == BLOCK_SIZE && remaining > 0) {
            incrementCounter(BLOCK_SIZE)
            compress(buffer, 0, false)
            bufferOffset = 0
        }

        while (remaining > BLOCK_SIZE) {
            incrementCounter(BLOCK_SIZE)
            compress(input, pos, false)
            pos += BLOCK_SIZE
            remaining -= BLOCK_SIZE
        }

        if (remaining > 0) {
            input.copyInto(buffer, bufferOffset, pos, pos + remaining)
            bufferOffset += remaining
        }
        return this
    }

    fun finalize(): ByteArray {
        for (i in bufferOffset until BLOCK_SIZE) buffer[i] = 0
        incrementCounter(bufferOffset)
        compress(buffer, 0, true)

        val out = ByteArray(digestLength)
        val tmp = ByteArray(MAX_DIGEST)
        for (i in 0..7) storeInt(h[i], tmp, i * 4)
        tmp.copyInto(out, 0, 0, digestLength)
        return out
    }

    // ---- Private helpers ----

    private fun incrementCounter(inc: Int) {
        val old = t0
        t0 += inc
        if (t0.toUInt() < old.toUInt()) t1++
    }

    private fun compress(block: ByteArray, off: Int, last: Boolean) {
        for (i in 0..15) m[i] = loadInt(block, off + i * 4)

        var v0 = h[0]; var v1 = h[1]; var v2 = h[2]; var v3 = h[3]
        var v4 = h[4]; var v5 = h[5]; var v6 = h[6]; var v7 = h[7]
        var v8 = IV[0]; var v9 = IV[1]; var v10 = IV[2]; var v11 = IV[3]
        var v12 = IV[4] xor t0; var v13 = IV[5] xor t1
        var v14 = if (last) IV[6] xor -1 else IV[6]
        var v15 = if (last && lastNode) IV[7] xor -1 else IV[7]

        for (round in 0 until ROUNDS) {
            val s = (round % 10) shl 4
            // Column step
            v0 += v4 + m[SIGMA_FLAT[s]]; v12 = (v12 xor v0).rotateRight(16)
            v8 += v12; v4 = (v4 xor v8).rotateRight(12)
            v0 += v4 + m[SIGMA_FLAT[s + 1]]; v12 = (v12 xor v0).rotateRight(8)
            v8 += v12; v4 = (v4 xor v8).rotateRight(7)

            v1 += v5 + m[SIGMA_FLAT[s + 2]]; v13 = (v13 xor v1).rotateRight(16)
            v9 += v13; v5 = (v5 xor v9).rotateRight(12)
            v1 += v5 + m[SIGMA_FLAT[s + 3]]; v13 = (v13 xor v1).rotateRight(8)
            v9 += v13; v5 = (v5 xor v9).rotateRight(7)

            v2 += v6 + m[SIGMA_FLAT[s + 4]]; v14 = (v14 xor v2).rotateRight(16)
            v10 += v14; v6 = (v6 xor v10).rotateRight(12)
            v2 += v6 + m[SIGMA_FLAT[s + 5]]; v14 = (v14 xor v2).rotateRight(8)
            v10 += v14; v6 = (v6 xor v10).rotateRight(7)

            v3 += v7 + m[SIGMA_FLAT[s + 6]]; v15 = (v15 xor v3).rotateRight(16)
            v11 += v15; v7 = (v7 xor v11).rotateRight(12)
            v3 += v7 + m[SIGMA_FLAT[s + 7]]; v15 = (v15 xor v3).rotateRight(8)
            v11 += v15; v7 = (v7 xor v11).rotateRight(7)

            // Diagonal step
            v0 += v5 + m[SIGMA_FLAT[s + 8]]; v15 = (v15 xor v0).rotateRight(16)
            v10 += v15; v5 = (v5 xor v10).rotateRight(12)
            v0 += v5 + m[SIGMA_FLAT[s + 9]]; v15 = (v15 xor v0).rotateRight(8)
            v10 += v15; v5 = (v5 xor v10).rotateRight(7)

            v1 += v6 + m[SIGMA_FLAT[s + 10]]; v12 = (v12 xor v1).rotateRight(16)
            v11 += v12; v6 = (v6 xor v11).rotateRight(12)
            v1 += v6 + m[SIGMA_FLAT[s + 11]]; v12 = (v12 xor v1).rotateRight(8)
            v11 += v12; v6 = (v6 xor v11).rotateRight(7)

            v2 += v7 + m[SIGMA_FLAT[s + 12]]; v13 = (v13 xor v2).rotateRight(16)
            v8 += v13; v7 = (v7 xor v8).rotateRight(12)
            v2 += v7 + m[SIGMA_FLAT[s + 13]]; v13 = (v13 xor v2).rotateRight(8)
            v8 += v13; v7 = (v7 xor v8).rotateRight(7)

            v3 += v4 + m[SIGMA_FLAT[s + 14]]; v14 = (v14 xor v3).rotateRight(16)
            v9 += v14; v4 = (v4 xor v9).rotateRight(12)
            v3 += v4 + m[SIGMA_FLAT[s + 15]]; v14 = (v14 xor v3).rotateRight(8)
            v9 += v14; v4 = (v4 xor v9).rotateRight(7)
        }

        h[0] = h[0] xor v0 xor v8;  h[1] = h[1] xor v1 xor v9
        h[2] = h[2] xor v2 xor v10; h[3] = h[3] xor v3 xor v11
        h[4] = h[4] xor v4 xor v12; h[5] = h[5] xor v5 xor v13
        h[6] = h[6] xor v6 xor v14; h[7] = h[7] xor v7 xor v15
    }
}
