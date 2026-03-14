package blake.hash.internal

// BLAKE3 constants and core operations.

internal object Blake3Core {

    const val BLOCK_LEN = 64
    const val CHUNK_LEN = 1024
    const val KEY_LEN = 32
    const val OUT_LEN = 32

    // Flags
    const val CHUNK_START = 1
    const val CHUNK_END = 2
    const val PARENT = 4
    const val ROOT = 8
    const val KEYED_HASH = 16
    const val DERIVE_KEY_CONTEXT = 32
    const val DERIVE_KEY_MATERIAL = 64

    // IV (SHA-256 / BLAKE2s IV)
    val IV = intArrayOf(
        0x6a09e667, 0xbb67ae85.toInt(), 0x3c6ef372, 0xa54ff53a.toInt(),
        0x510e527f, 0x9b05688c.toInt(), 0x1f83d9ab, 0x5be0cd19
    )

    // Pre-computed message word permutation schedule for 7 rounds.
    // Round 0 is identity; each subsequent round applies the fixed permutation.
    private val MSG_SCHEDULE = arrayOf(
        intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15),
        intArrayOf(2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8),
        intArrayOf(3, 4, 10, 12, 13, 2, 7, 14, 6, 5, 9, 0, 11, 15, 8, 1),
        intArrayOf(10, 7, 12, 9, 14, 3, 13, 15, 4, 0, 11, 2, 5, 8, 1, 6),
        intArrayOf(12, 13, 9, 11, 15, 10, 14, 8, 7, 2, 5, 3, 0, 1, 6, 4),
        intArrayOf(9, 14, 11, 5, 8, 12, 15, 1, 13, 3, 0, 10, 2, 6, 4, 7),
        intArrayOf(11, 15, 5, 0, 1, 9, 8, 6, 14, 10, 2, 12, 3, 4, 7, 13),
    )

    /** BLAKE3 compression function. Returns all 16 output words. */
    fun compress(
        chainingValue: IntArray,
        blockWords: IntArray,
        counter: Long,
        blockLen: Int,
        flags: Int
    ): IntArray {
        val v = IntArray(16)
        chainingValue.copyInto(v, 0, 0, 8)
        v[8] = IV[0]; v[9] = IV[1]; v[10] = IV[2]; v[11] = IV[3]
        v[12] = counter.toInt()
        v[13] = (counter ushr 32).toInt()
        v[14] = blockLen
        v[15] = flags

        for (round in 0..6) {
            val s = MSG_SCHEDULE[round]
            // Column step
            g(v, 0, 4, 8, 12, blockWords[s[0]], blockWords[s[1]])
            g(v, 1, 5, 9, 13, blockWords[s[2]], blockWords[s[3]])
            g(v, 2, 6, 10, 14, blockWords[s[4]], blockWords[s[5]])
            g(v, 3, 7, 11, 15, blockWords[s[6]], blockWords[s[7]])
            // Diagonal step
            g(v, 0, 5, 10, 15, blockWords[s[8]], blockWords[s[9]])
            g(v, 1, 6, 11, 12, blockWords[s[10]], blockWords[s[11]])
            g(v, 2, 7, 8, 13, blockWords[s[12]], blockWords[s[13]])
            g(v, 3, 4, 9, 14, blockWords[s[14]], blockWords[s[15]])
        }

        val out = IntArray(16)
        for (i in 0..7) {
            out[i] = v[i] xor v[i + 8]
            out[i + 8] = v[i + 8] xor chainingValue[i]
        }
        return out
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

    /** Read a 32-bit little-endian word from [buf] at [offset]. */
    fun leToInt(buf: ByteArray, offset: Int): Int {
        return (buf[offset].toInt() and 0xFF) or
                ((buf[offset + 1].toInt() and 0xFF) shl 8) or
                ((buf[offset + 2].toInt() and 0xFF) shl 16) or
                ((buf[offset + 3].toInt() and 0xFF) shl 24)
    }

    /** Write a 32-bit little-endian word to [buf] at [offset]. */
    fun intToLe(value: Int, buf: ByteArray, offset: Int) {
        buf[offset] = value.toByte()
        buf[offset + 1] = (value ushr 8).toByte()
        buf[offset + 2] = (value ushr 16).toByte()
        buf[offset + 3] = (value ushr 24).toByte()
    }

    /** Parse a 64-byte (or shorter, zero-padded) block into 16 little-endian words. */
    fun bytesToWords(block: ByteArray, offset: Int, len: Int): IntArray {
        val padded = ByteArray(BLOCK_LEN)
        block.copyInto(padded, 0, offset, offset + len)
        return IntArray(16) { leToInt(padded, it * 4) }
    }

    /** Convert 8 words to 32 bytes (little-endian). */
    fun wordsToBytes(words: IntArray, count: Int = words.size): ByteArray {
        val out = ByteArray(count * 4)
        for (i in 0 until count) {
            intToLe(words[i], out, i * 4)
        }
        return out
    }

    // ---- Output node: captures inputs needed for root finalization / XOF ----

    class Output(
        val chainingValue: IntArray,
        val blockWords: IntArray,
        val counter: Long,
        val blockLen: Int,
        val flags: Int
    ) {
        /** First 8 words of compression output (used as chaining value). */
        fun chainingValueWords(): IntArray {
            return compress(chainingValue, blockWords, counter, blockLen, flags)
                .copyOfRange(0, 8)
        }

        /** First 8 words of root compression (includes ROOT flag). */
        fun rootChainingValue(): IntArray {
            return compress(chainingValue, blockWords, counter, blockLen, flags or ROOT)
                .copyOfRange(0, 8)
        }

        /** Produce arbitrary-length output (XOF). */
        fun rootOutputBytes(outputLen: Int): ByteArray {
            val result = ByteArray(outputLen)
            var outputIndex = 0
            var blockCounter = 0L
            while (outputIndex < outputLen) {
                val words = compress(
                    chainingValue, blockWords, blockCounter,
                    blockLen, flags or ROOT
                )
                val bytes = wordsToBytes(words)
                val take = minOf(bytes.size, outputLen - outputIndex)
                bytes.copyInto(result, outputIndex, 0, take)
                outputIndex += take
                blockCounter++
            }
            return result
        }
    }

    // ---- Chunk state: processes one 1024-byte chunk ----

    class ChunkState(
        private val key: IntArray,
        val chunkCounter: Long,
        private val baseFlags: Int
    ) {
        private var chainingValue = key.copyOf()
        private var block = ByteArray(BLOCK_LEN)
        private var blockLen = 0
        private var blocksCompressed = 0
        var bytesConsumed = 0
            private set

        val isComplete: Boolean get() = bytesConsumed == CHUNK_LEN

        fun update(input: ByteArray, inputOffset: Int, inputLen: Int) {
            var offset = inputOffset
            var remaining = inputLen
            while (remaining > 0) {
                if (blockLen == BLOCK_LEN) {
                    // Block is full — compress it
                    val blockWords = bytesToWords(block, 0, BLOCK_LEN)
                    var flags = baseFlags
                    if (blocksCompressed == 0) flags = flags or CHUNK_START
                    chainingValue = compress(
                        chainingValue, blockWords, chunkCounter,
                        BLOCK_LEN, flags
                    ).copyOfRange(0, 8)
                    blocksCompressed++
                    block = ByteArray(BLOCK_LEN)
                    blockLen = 0
                }
                val take = minOf(BLOCK_LEN - blockLen, remaining)
                input.copyInto(block, blockLen, offset, offset + take)
                blockLen += take
                bytesConsumed += take
                offset += take
                remaining -= take
            }
        }

        /** Return the Output for this chunk's final block. */
        fun output(): Output {
            val blockWords = bytesToWords(block, 0, blockLen)
            var flags = baseFlags or CHUNK_END
            if (blocksCompressed == 0) flags = flags or CHUNK_START
            return Output(chainingValue, blockWords, chunkCounter, blockLen, flags)
        }
    }

    // ---- Parent node helper ----

    fun parentOutput(
        leftChild: IntArray,
        rightChild: IntArray,
        key: IntArray,
        flags: Int
    ): Output {
        val blockWords = IntArray(16)
        leftChild.copyInto(blockWords, 0, 0, 8)
        rightChild.copyInto(blockWords, 8, 0, 8)
        return Output(key, blockWords, 0, BLOCK_LEN, flags or PARENT)
    }

    fun parentChainingValue(
        leftChild: IntArray,
        rightChild: IntArray,
        key: IntArray,
        flags: Int
    ): IntArray {
        return parentOutput(leftChild, rightChild, key, flags).chainingValueWords()
    }
}
