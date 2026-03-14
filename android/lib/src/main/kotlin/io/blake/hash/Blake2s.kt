package io.blake.hash

import io.blake.hash.internal.*

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
        val v = IntArray(16)
        val m = IntArray(16)

        for (i in 0..7) v[i] = h[i]
        v[8]  = IV[0]
        v[9]  = IV[1]
        v[10] = IV[2]
        v[11] = IV[3]
        v[12] = IV[4] xor t0
        v[13] = IV[5] xor t1
        v[14] = if (last) IV[6] xor -1 else IV[6]
        v[15] = if (last && lastNode) IV[7] xor -1 else IV[7]

        for (i in 0..15) m[i] = loadInt(block, off + i * 4)

        for (round in 0 until ROUNDS) {
            val s = SIGMA[round % 10]
            g(v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]])
            g(v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]])
            g(v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]])
            g(v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]])
            g(v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]])
            g(v, 1, 6, 11, 12, m[s[10]], m[s[11]])
            g(v, 2, 7,  8, 13, m[s[12]], m[s[13]])
            g(v, 3, 4,  9, 14, m[s[14]], m[s[15]])
        }

        for (i in 0..7) h[i] = h[i] xor v[i] xor v[i + 8]
    }

    private fun g(v: IntArray, a: Int, b: Int, c: Int, d: Int, x: Int, y: Int) {
        v[a] = v[a] + v[b] + x
        v[d] = (v[d] xor v[a]).rotateRight(16)
        v[c] = v[c] + v[d]
        v[b] = (v[b] xor v[c]).rotateRight(12)
        v[a] = v[a] + v[b] + y
        v[d] = (v[d] xor v[a]).rotateRight(8)
        v[c] = v[c] + v[d]
        v[b] = (v[b] xor v[c]).rotateRight(7)
    }
}
