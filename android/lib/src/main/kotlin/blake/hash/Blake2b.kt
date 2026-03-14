package blake.hash

import blake.hash.internal.*

/**
 * BLAKE2b cryptographic hash function.
 *
 * 64-bit variant with 128-byte blocks and up to 64-byte digests.
 */
public class Blake2b private constructor() {

    public companion object {
        private const val BLOCK_SIZE = 128
        private const val MAX_DIGEST = 64
        private const val MAX_KEY = 64

        /**
         * One-shot hash: returns the BLAKE2b digest of [input].
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
     * Incremental BLAKE2b hasher for streaming data.
     */
    public class Hasher @JvmOverloads public constructor(
        digestLength: Int = MAX_DIGEST,
        key: ByteArray = ByteArray(0),
        salt: ByteArray = ByteArray(0),
        personalization: ByteArray = ByteArray(0)
    ) {
        private val engine = Blake2bEngine(
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
// Internal engine – also used by Blake2bp
// ---------------------------------------------------------------------------

internal class Blake2bEngine(
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
        const val BLOCK_SIZE = 128
        const val MAX_DIGEST = 64
        private const val ROUNDS = 12

        val IV = longArrayOf(
            0x6A09E667F3BCC908L, -0x4498517A7B3558C5L,
            0x3C6EF372FE94F82BL, -0x5AB00AC5A0E2C90FL,
            0x510E527FADE682D1L, -0x64FA9773D4C193E1L,
            0x1F83D9ABFB41BD6BL,  0x5BE0CD19137E2179L
        )
    }

    private val h = LongArray(8)
    private var t0: Long = 0L
    private var t1: Long = 0L
    private val buffer = ByteArray(BLOCK_SIZE)
    private var bufferOffset = 0
    internal var lastNode: Boolean = false

    // Pre-allocated message word array — avoids per-compress allocation
    private val m = LongArray(16)

    init {
        require(digestLength in 1..MAX_DIGEST) { "digestLength must be 1..64" }
        require(key.size <= MAX_DIGEST) { "key must be 0..64 bytes" }
        require(salt.size <= 16) { "salt must be 0..16 bytes" }
        require(personalization.size <= 16) { "personalization must be 0..16 bytes" }

        // Build the 64-byte parameter block
        val p = ByteArray(64)
        p[0] = digestLength.toByte()
        p[1] = paramKeyLength.toByte()
        p[2] = fanout.toByte()
        p[3] = depth.toByte()
        storeInt(leafLength, p, 4)
        storeLong(nodeOffset, p, 8)
        p[16] = nodeDepth.toByte()
        p[17] = innerLength.toByte()
        // bytes 18-31 reserved (zero)
        if (salt.isNotEmpty()) salt.copyInto(p, 32)
        if (personalization.isNotEmpty()) personalization.copyInto(p, 48)

        // h = IV xor paramBlock
        for (i in 0..7) {
            h[i] = IV[i] xor loadLong(p, i * 8)
        }

        // If keyed, pad key to a full block and buffer it
        if (key.isNotEmpty()) {
            key.copyInto(buffer)
            // rest of buffer is already zero
            bufferOffset = BLOCK_SIZE
        }
    }

    fun update(input: ByteArray, offset: Int, length: Int): Blake2bEngine {
        var pos = offset
        var remaining = length
        if (remaining == 0) return this

        // 1. Try to fill partially-full buffer
        if (bufferOffset > 0 && remaining > 0) {
            val space = BLOCK_SIZE - bufferOffset
            val n = minOf(space, remaining)
            input.copyInto(buffer, bufferOffset, pos, pos + n)
            bufferOffset += n
            pos += n
            remaining -= n
        }

        // 2. If buffer is full and there is more data, compress it
        if (bufferOffset == BLOCK_SIZE && remaining > 0) {
            incrementCounter(BLOCK_SIZE)
            compress(buffer, 0, false)
            bufferOffset = 0
        }

        // 3. Compress full blocks directly from input (keep last partial/full block)
        while (remaining > BLOCK_SIZE) {
            incrementCounter(BLOCK_SIZE)
            compress(input, pos, false)
            pos += BLOCK_SIZE
            remaining -= BLOCK_SIZE
        }

        // 4. Buffer leftover
        if (remaining > 0) {
            input.copyInto(buffer, bufferOffset, pos, pos + remaining)
            bufferOffset += remaining
        }
        return this
    }

    fun finalize(): ByteArray {
        // Zero-pad remaining buffer
        for (i in bufferOffset until BLOCK_SIZE) buffer[i] = 0
        incrementCounter(bufferOffset)
        compress(buffer, 0, true)

        val out = ByteArray(digestLength)
        val tmp = ByteArray(MAX_DIGEST)
        for (i in 0..7) storeLong(h[i], tmp, i * 8)
        tmp.copyInto(out, 0, 0, digestLength)
        return out
    }

    // ---- Private helpers ----

    private fun incrementCounter(inc: Int) {
        val old = t0
        t0 += inc.toLong()
        if (t0.toULong() < old.toULong()) t1++
    }

    private fun compress(block: ByteArray, off: Int, last: Boolean) {
        for (i in 0..15) m[i] = loadLong(block, off + i * 8)

        // Local variables for the working vector — eliminates array bounds checks
        var v0 = h[0]; var v1 = h[1]; var v2 = h[2]; var v3 = h[3]
        var v4 = h[4]; var v5 = h[5]; var v6 = h[6]; var v7 = h[7]
        var v8 = IV[0]; var v9 = IV[1]; var v10 = IV[2]; var v11 = IV[3]
        var v12 = IV[4] xor t0; var v13 = IV[5] xor t1
        var v14 = if (last) IV[6] xor -1L else IV[6]
        var v15 = if (last && lastNode) IV[7] xor -1L else IV[7]

        for (round in 0 until ROUNDS) {
            val s = (round % 10) shl 4
            // Column step
            v0 += v4 + m[SIGMA_FLAT[s]]; v12 = (v12 xor v0).rotateRight(32)
            v8 += v12; v4 = (v4 xor v8).rotateRight(24)
            v0 += v4 + m[SIGMA_FLAT[s + 1]]; v12 = (v12 xor v0).rotateRight(16)
            v8 += v12; v4 = (v4 xor v8).rotateRight(63)

            v1 += v5 + m[SIGMA_FLAT[s + 2]]; v13 = (v13 xor v1).rotateRight(32)
            v9 += v13; v5 = (v5 xor v9).rotateRight(24)
            v1 += v5 + m[SIGMA_FLAT[s + 3]]; v13 = (v13 xor v1).rotateRight(16)
            v9 += v13; v5 = (v5 xor v9).rotateRight(63)

            v2 += v6 + m[SIGMA_FLAT[s + 4]]; v14 = (v14 xor v2).rotateRight(32)
            v10 += v14; v6 = (v6 xor v10).rotateRight(24)
            v2 += v6 + m[SIGMA_FLAT[s + 5]]; v14 = (v14 xor v2).rotateRight(16)
            v10 += v14; v6 = (v6 xor v10).rotateRight(63)

            v3 += v7 + m[SIGMA_FLAT[s + 6]]; v15 = (v15 xor v3).rotateRight(32)
            v11 += v15; v7 = (v7 xor v11).rotateRight(24)
            v3 += v7 + m[SIGMA_FLAT[s + 7]]; v15 = (v15 xor v3).rotateRight(16)
            v11 += v15; v7 = (v7 xor v11).rotateRight(63)

            // Diagonal step
            v0 += v5 + m[SIGMA_FLAT[s + 8]]; v15 = (v15 xor v0).rotateRight(32)
            v10 += v15; v5 = (v5 xor v10).rotateRight(24)
            v0 += v5 + m[SIGMA_FLAT[s + 9]]; v15 = (v15 xor v0).rotateRight(16)
            v10 += v15; v5 = (v5 xor v10).rotateRight(63)

            v1 += v6 + m[SIGMA_FLAT[s + 10]]; v12 = (v12 xor v1).rotateRight(32)
            v11 += v12; v6 = (v6 xor v11).rotateRight(24)
            v1 += v6 + m[SIGMA_FLAT[s + 11]]; v12 = (v12 xor v1).rotateRight(16)
            v11 += v12; v6 = (v6 xor v11).rotateRight(63)

            v2 += v7 + m[SIGMA_FLAT[s + 12]]; v13 = (v13 xor v2).rotateRight(32)
            v8 += v13; v7 = (v7 xor v8).rotateRight(24)
            v2 += v7 + m[SIGMA_FLAT[s + 13]]; v13 = (v13 xor v2).rotateRight(16)
            v8 += v13; v7 = (v7 xor v8).rotateRight(63)

            v3 += v4 + m[SIGMA_FLAT[s + 14]]; v14 = (v14 xor v3).rotateRight(32)
            v9 += v14; v4 = (v4 xor v9).rotateRight(24)
            v3 += v4 + m[SIGMA_FLAT[s + 15]]; v14 = (v14 xor v3).rotateRight(16)
            v9 += v14; v4 = (v4 xor v9).rotateRight(63)
        }

        h[0] = h[0] xor v0 xor v8;  h[1] = h[1] xor v1 xor v9
        h[2] = h[2] xor v2 xor v10; h[3] = h[3] xor v3 xor v11
        h[4] = h[4] xor v4 xor v12; h[5] = h[5] xor v5 xor v13
        h[6] = h[6] xor v6 xor v14; h[7] = h[7] xor v7 xor v15
    }
}
