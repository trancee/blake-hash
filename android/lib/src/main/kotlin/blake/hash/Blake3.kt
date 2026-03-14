package blake.hash

import blake.hash.internal.BLAKE3Core
import blake.hash.internal.BLAKE3Core.CHUNK_LEN
import blake.hash.internal.BLAKE3Core.DERIVE_KEY_CONTEXT
import blake.hash.internal.BLAKE3Core.DERIVE_KEY_MATERIAL
import blake.hash.internal.BLAKE3Core.IV
import blake.hash.internal.BLAKE3Core.KEYED_HASH
import blake.hash.internal.BLAKE3Core.KEY_LEN
import blake.hash.internal.BLAKE3Core.OUT_LEN

/**
 * BLAKE3 cryptographic hash function.
 *
 * Supports hash, keyed hash (MAC/PRF), and key derivation modes,
 * with extendable output (XOF).
 */
public class BLAKE3 private constructor() {

    public companion object {
        /** Hash mode — returns 32-byte digest. */
        public fun hash(input: ByteArray): ByteArray {
            return Hasher().update(input).finalize()
        }

        /** Keyed hash mode (MAC/PRF) — key must be exactly 32 bytes. */
        public fun keyedHash(key: ByteArray, input: ByteArray): ByteArray {
            return Hasher(key).update(input).finalize()
        }

        /** Key derivation mode — returns 32-byte derived key. */
        public fun deriveKey(context: String, keyMaterial: ByteArray): ByteArray {
            return Hasher.deriveKey(context).update(keyMaterial).finalize()
        }
    }

    /**
     * Incremental BLAKE3 hasher supporting streaming updates and XOF output.
     */
    public class Hasher private constructor(
        private val key: IntArray,
        private val baseFlags: Int
    ) {
        private var chunkState = BLAKE3Core.ChunkState(key, 0, baseFlags)
        private val cvStack = Array(54) { IntArray(8) } // max tree depth
        private var cvStackLen = 0
        private var chunkCount: Long = 0

        /** Hash mode. */
        public constructor() : this(IV.copyOf(), 0)

        /** Keyed hash mode — key must be exactly 32 bytes. */
        public constructor(key: ByteArray) : this(keyWords(key), KEYED_HASH)

        public companion object {
            /** Create a derive_key hasher (phase 2). */
            public fun deriveKey(context: String): Hasher {
                val contextBytes = context.encodeToByteArray()
                val contextHasher = Hasher(IV.copyOf(), DERIVE_KEY_CONTEXT)
                contextHasher.update(contextBytes)
                val contextKey = contextHasher.rootOutput().rootChainingValue()
                return Hasher(contextKey, DERIVE_KEY_MATERIAL)
            }

            private fun keyWords(key: ByteArray): IntArray {
                require(key.size == KEY_LEN) { "Key must be exactly $KEY_LEN bytes" }
                return IntArray(8) { BLAKE3Core.leToInt(key, it * 4) }
            }
        }

        public fun update(input: ByteArray): Hasher = update(input, 0, input.size)

        public fun update(input: ByteArray, offset: Int, length: Int): Hasher {
            var pos = offset
            var remaining = length
            while (remaining > 0) {
                if (chunkState.isComplete) {
                    completeChunk()
                }
                val take = minOf(CHUNK_LEN - chunkState.bytesConsumed, remaining)
                chunkState.update(input, pos, take)
                pos += take
                remaining -= take
            }
            return this
        }

        /** Finalize with default 32-byte output. */
        public fun finalize(): ByteArray = finalizeXof(OUT_LEN)

        /** Finalize with arbitrary output length (XOF). */
        public fun finalizeXof(outputLength: Int): ByteArray {
            return rootOutput().rootOutputBytes(outputLength)
        }

        // ---- Internal tree management ----

        private fun completeChunk() {
            val chunkCv = chunkState.output().chainingValueWords()
            chunkCount++
            addChunkCv(chunkCv)
            chunkState = BLAKE3Core.ChunkState(key, chunkCount, baseFlags)
        }

        /**
         * After pushing a chunk's chaining value, merge adjacent pairs that
         * form complete subtrees. A complete subtree at level L exists when
         * bit L of the total chunk count is 0 (the bit just cleared).
         */
        private fun addChunkCv(cv: IntArray) {
            cv.copyInto(cvStack[cvStackLen])
            cvStackLen++
            var totalChunks = chunkCount
            while (cvStackLen > 1 && (totalChunks and 1L) == 0L) {
                cvStackLen--
                val right = cvStack[cvStackLen]
                cvStackLen--
                val left = cvStack[cvStackLen]
                val parent = BLAKE3Core.parentChainingValue(left, right, key, baseFlags)
                parent.copyInto(cvStack[cvStackLen])
                cvStackLen++
                totalChunks = totalChunks ushr 1
            }
        }

        private fun rootOutput(): BLAKE3Core.Output {
            // Finalize the current (possibly partial) chunk
            var output = chunkState.output()
            var cv = output.chainingValueWords()

            // If there are stacked CVs, merge right-to-left
            var idx = cvStackLen - 1
            if (idx < 0) {
                // Single chunk — it is the root
                return output
            }

            // The current chunk is the rightmost child
            while (idx > 0) {
                cv = BLAKE3Core.parentChainingValue(cvStack[idx], cv, key, baseFlags)
                idx--
            }

            // Last merge gets ROOT flag via parentOutput
            return BLAKE3Core.parentOutput(cvStack[0], cv, key, baseFlags)
        }
    }
}
