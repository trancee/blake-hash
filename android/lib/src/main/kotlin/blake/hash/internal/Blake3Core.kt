package blake.hash.internal

// BLAKE3 constants and core operations.

internal object BLAKE3Core {

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

    // Flattened message word permutation — indexed as MSG_PERM[round * 16 + i]
    @JvmField
    val MSG_PERM = intArrayOf(
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8,
        3, 4, 10, 12, 13, 2, 7, 14, 6, 5, 9, 0, 11, 15, 8, 1,
        10, 7, 12, 9, 14, 3, 13, 15, 4, 0, 11, 2, 5, 8, 1, 6,
        12, 13, 9, 11, 15, 10, 14, 8, 7, 2, 5, 3, 0, 1, 6, 4,
        9, 14, 11, 5, 8, 12, 15, 1, 13, 3, 0, 10, 2, 6, 4, 7,
        11, 15, 5, 0, 1, 9, 8, 6, 14, 10, 2, 12, 3, 4, 7, 13,
    )

    /** BLAKE3 compression function. Returns all 16 output words. */
    fun compress(
        chainingValue: IntArray,
        blockWords: IntArray,
        counter: Long,
        blockLen: Int,
        flags: Int
    ): IntArray {
        return compress(chainingValue, blockWords, counter, blockLen, flags, IntArray(16))
    }

    /** BLAKE3 compression function writing into a pre-allocated output array. */
    fun compress(
        chainingValue: IntArray,
        blockWords: IntArray,
        counter: Long,
        blockLen: Int,
        flags: Int,
        out: IntArray
    ): IntArray {
        // Local variables for the working vector — eliminates array bounds checks
        var v0 = chainingValue[0]; var v1 = chainingValue[1]
        var v2 = chainingValue[2]; var v3 = chainingValue[3]
        var v4 = chainingValue[4]; var v5 = chainingValue[5]
        var v6 = chainingValue[6]; var v7 = chainingValue[7]
        var v8 = IV[0]; var v9 = IV[1]; var v10 = IV[2]; var v11 = IV[3]
        var v12 = counter.toInt(); var v13 = (counter ushr 32).toInt()
        var v14 = blockLen; var v15 = flags

        for (round in 0..6) {
            val p = round shl 4
            // Column step
            v0 += v4 + blockWords[MSG_PERM[p]]; v12 = (v12 xor v0).rotateRight(16)
            v8 += v12; v4 = (v4 xor v8).rotateRight(12)
            v0 += v4 + blockWords[MSG_PERM[p + 1]]; v12 = (v12 xor v0).rotateRight(8)
            v8 += v12; v4 = (v4 xor v8).rotateRight(7)

            v1 += v5 + blockWords[MSG_PERM[p + 2]]; v13 = (v13 xor v1).rotateRight(16)
            v9 += v13; v5 = (v5 xor v9).rotateRight(12)
            v1 += v5 + blockWords[MSG_PERM[p + 3]]; v13 = (v13 xor v1).rotateRight(8)
            v9 += v13; v5 = (v5 xor v9).rotateRight(7)

            v2 += v6 + blockWords[MSG_PERM[p + 4]]; v14 = (v14 xor v2).rotateRight(16)
            v10 += v14; v6 = (v6 xor v10).rotateRight(12)
            v2 += v6 + blockWords[MSG_PERM[p + 5]]; v14 = (v14 xor v2).rotateRight(8)
            v10 += v14; v6 = (v6 xor v10).rotateRight(7)

            v3 += v7 + blockWords[MSG_PERM[p + 6]]; v15 = (v15 xor v3).rotateRight(16)
            v11 += v15; v7 = (v7 xor v11).rotateRight(12)
            v3 += v7 + blockWords[MSG_PERM[p + 7]]; v15 = (v15 xor v3).rotateRight(8)
            v11 += v15; v7 = (v7 xor v11).rotateRight(7)

            // Diagonal step
            v0 += v5 + blockWords[MSG_PERM[p + 8]]; v15 = (v15 xor v0).rotateRight(16)
            v10 += v15; v5 = (v5 xor v10).rotateRight(12)
            v0 += v5 + blockWords[MSG_PERM[p + 9]]; v15 = (v15 xor v0).rotateRight(8)
            v10 += v15; v5 = (v5 xor v10).rotateRight(7)

            v1 += v6 + blockWords[MSG_PERM[p + 10]]; v12 = (v12 xor v1).rotateRight(16)
            v11 += v12; v6 = (v6 xor v11).rotateRight(12)
            v1 += v6 + blockWords[MSG_PERM[p + 11]]; v12 = (v12 xor v1).rotateRight(8)
            v11 += v12; v6 = (v6 xor v11).rotateRight(7)

            v2 += v7 + blockWords[MSG_PERM[p + 12]]; v13 = (v13 xor v2).rotateRight(16)
            v8 += v13; v7 = (v7 xor v8).rotateRight(12)
            v2 += v7 + blockWords[MSG_PERM[p + 13]]; v13 = (v13 xor v2).rotateRight(8)
            v8 += v13; v7 = (v7 xor v8).rotateRight(7)

            v3 += v4 + blockWords[MSG_PERM[p + 14]]; v14 = (v14 xor v3).rotateRight(16)
            v9 += v14; v4 = (v4 xor v9).rotateRight(12)
            v3 += v4 + blockWords[MSG_PERM[p + 15]]; v14 = (v14 xor v3).rotateRight(8)
            v9 += v14; v4 = (v4 xor v9).rotateRight(7)
        }

        out[0] = v0 xor v8;  out[8]  = v8 xor chainingValue[0]
        out[1] = v1 xor v9;  out[9]  = v9 xor chainingValue[1]
        out[2] = v2 xor v10; out[10] = v10 xor chainingValue[2]
        out[3] = v3 xor v11; out[11] = v11 xor chainingValue[3]
        out[4] = v4 xor v12; out[12] = v12 xor chainingValue[4]
        out[5] = v5 xor v13; out[13] = v13 xor chainingValue[5]
        out[6] = v6 xor v14; out[14] = v14 xor chainingValue[6]
        out[7] = v7 xor v15; out[15] = v15 xor chainingValue[7]
        return out
    }

    /** Read a 32-bit little-endian word from [buf] at [offset]. */
    fun leToInt(buf: ByteArray, offset: Int): Int = INT_LE.get(buf, offset) as Int

    /** Write a 32-bit little-endian word to [buf] at [offset]. */
    fun intToLe(value: Int, buf: ByteArray, offset: Int) { INT_LE.set(buf, offset, value) }

    /** Parse a 64-byte (or shorter, zero-padded) block into 16 little-endian words. */
    fun bytesToWords(block: ByteArray, offset: Int, len: Int): IntArray {
        val words = IntArray(16)
        val fullWords = len / 4
        for (i in 0 until fullWords) {
            words[i] = leToInt(block, offset + i * 4)
        }
        // Handle trailing partial word (if len is not a multiple of 4)
        val remainder = len % 4
        if (remainder > 0) {
            var w = 0
            val base = offset + fullWords * 4
            for (i in 0 until remainder) {
                w = w or ((block[base + i].toInt() and 0xFF) shl (i * 8))
            }
            words[fullWords] = w
        }
        // Remaining words are already 0
        return words
    }

    /** Parse a full 64-byte block into a pre-allocated 16-word array. */
    fun bytesToWords(block: ByteArray, offset: Int, len: Int, dest: IntArray) {
        val fullWords = len / 4
        for (i in 0 until fullWords) {
            dest[i] = leToInt(block, offset + i * 4)
        }
        val remainder = len % 4
        if (remainder > 0) {
            var w = 0
            val base = offset + fullWords * 4
            for (i in 0 until remainder) {
                w = w or ((block[base + i].toInt() and 0xFF) shl (i * 8))
            }
            dest[fullWords] = w
            for (i in fullWords + 1..15) dest[i] = 0
        } else {
            for (i in fullWords..15) dest[i] = 0
        }
    }

    /** Convert words to bytes (little-endian). */
    fun wordsToBytes(words: IntArray, count: Int = words.size): ByteArray {
        val out = ByteArray(count * 4)
        for (i in 0 until count) {
            intToLe(words[i], out, i * 4)
        }
        return out
    }

    /** Write words directly to an existing byte buffer at the given offset. */
    fun wordsToBytesInto(words: IntArray, dest: ByteArray, destOffset: Int, wordCount: Int) {
        for (i in 0 until wordCount) {
            intToLe(words[i], dest, destOffset + i * 4)
        }
    }

    // ---- Output node: captures inputs needed for root finalization / XOF ----

    class Output(
        val chainingValue: IntArray,
        val blockWords: IntArray,
        val counter: Long,
        val blockLen: Int,
        val flags: Int
    ) {
        // Pre-allocated scratch arrays to avoid per-call allocation
        private val compressOut = IntArray(16)
        private val cvOut = IntArray(8)

        /** First 8 words of compression output (used as chaining value). */
        fun chainingValueWords(): IntArray {
            compress(chainingValue, blockWords, counter, blockLen, flags, compressOut)
            compressOut.copyInto(cvOut, 0, 0, 8)
            return cvOut
        }

        /** First 8 words of root compression into a pre-allocated destination. */
        fun chainingValueWordsInto(dest: IntArray) {
            compress(chainingValue, blockWords, counter, blockLen, flags, compressOut)
            compressOut.copyInto(dest, 0, 0, 8)
        }

        /** First 8 words of root compression (includes ROOT flag). */
        fun rootChainingValue(): IntArray {
            compress(chainingValue, blockWords, counter, blockLen, flags or ROOT, compressOut)
            val result = IntArray(8)
            compressOut.copyInto(result, 0, 0, 8)
            return result
        }

        /** Produce arbitrary-length output (XOF) — writes directly to result. */
        fun rootOutputBytes(outputLen: Int): ByteArray {
            val result = ByteArray(outputLen)
            var outputIndex = 0
            var blockCounter = 0L
            while (outputIndex < outputLen) {
                compress(
                    chainingValue, blockWords, blockCounter,
                    blockLen, flags or ROOT, compressOut
                )
                val available = 64 // 16 words * 4 bytes
                val take = minOf(available, outputLen - outputIndex)
                val wordCount = (take + 3) / 4
                wordsToBytesInto(compressOut, result, outputIndex, wordCount)
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
        private val block = ByteArray(BLOCK_LEN)
        private var blockLen = 0
        private var blocksCompressed = 0
        var bytesConsumed = 0
            private set

        // Pre-allocated arrays for hot-path compress calls
        private val blockWords = IntArray(16)
        private val compressOut = IntArray(16)

        val isComplete: Boolean get() = bytesConsumed == CHUNK_LEN

        fun update(input: ByteArray, inputOffset: Int, inputLen: Int) {
            var offset = inputOffset
            var remaining = inputLen
            while (remaining > 0) {
                if (blockLen == BLOCK_LEN) {
                    bytesToWords(block, 0, BLOCK_LEN, blockWords)
                    var flags = baseFlags
                    if (blocksCompressed == 0) flags = flags or CHUNK_START
                    compress(
                        chainingValue, blockWords, chunkCounter,
                        BLOCK_LEN, flags, compressOut
                    )
                    compressOut.copyInto(chainingValue, 0, 0, 8)
                    blocksCompressed++
                    block.fill(0)
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
            bytesToWords(block, 0, blockLen, blockWords)
            var flags = baseFlags or CHUNK_END
            if (blocksCompressed == 0) flags = flags or CHUNK_START
            return Output(chainingValue, blockWords.copyOf(), chunkCounter, blockLen, flags)
        }
    }

    // ---- Parent node helper ----

    // Pre-allocated scratch for parent node block words
    private val parentBlockWords = IntArray(16)

    fun parentOutput(
        leftChild: IntArray,
        rightChild: IntArray,
        key: IntArray,
        flags: Int
    ): Output {
        leftChild.copyInto(parentBlockWords, 0, 0, 8)
        rightChild.copyInto(parentBlockWords, 8, 0, 8)
        return Output(key, parentBlockWords.copyOf(), 0, BLOCK_LEN, flags or PARENT)
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
