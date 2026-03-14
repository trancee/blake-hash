package blake.hash

/**
 * BLAKE2sp – 8-way parallel BLAKE2s.
 *
 * Produces a 32-byte digest. Input is distributed across 8 leaf BLAKE2s
 * instances in round-robin 64-byte blocks; the 8 leaf digests are then
 * hashed by a single root BLAKE2s to produce the final output.
 */
public class Blake2sp private constructor() {

    public companion object {
        private const val PARALLELISM = 8
        private const val BLOCK_SIZE = Blake2sEngine.BLOCK_SIZE       // 64
        private const val DIGEST_LENGTH = Blake2sEngine.MAX_DIGEST    // 32
        private const val SUPERBLOCK = PARALLELISM * BLOCK_SIZE       // 512

        /**
         * One-shot hash: returns the 32-byte BLAKE2sp digest of [input].
         */
        public fun hash(
            input: ByteArray,
            key: ByteArray = ByteArray(0)
        ): ByteArray {
            val hasher = Hasher(key)
            hasher.update(input)
            return hasher.finalize()
        }
    }

    /**
     * Incremental BLAKE2sp hasher for streaming data.
     */
    public class Hasher @JvmOverloads public constructor(
        key: ByteArray = ByteArray(0)
    ) {
        private val leaves: Array<Blake2sEngine>
        private val root: Blake2sEngine
        private val buf = ByteArray(SUPERBLOCK)
        private var bufLen = 0

        init {
            val keyLen = key.size

            // Root first (reference order)
            root = Blake2sEngine(
                digestLength = DIGEST_LENGTH,
                fanout = PARALLELISM,
                depth = 2,
                leafLength = 0,
                nodeOffset = 0,
                nodeDepth = 1,
                innerLength = DIGEST_LENGTH,
                paramKeyLength = keyLen
            )

            // Create 8 leaf engines (node_offset = 0..7)
            leaves = Array(PARALLELISM) { i ->
                Blake2sEngine(
                    digestLength = DIGEST_LENGTH,
                    fanout = PARALLELISM,
                    depth = 2,
                    leafLength = 0,
                    nodeOffset = i.toLong(),
                    nodeDepth = 0,
                    innerLength = DIGEST_LENGTH,
                    paramKeyLength = keyLen
                )
            }

            // Only the last leaf and the root are marked as last-node
            root.lastNode = true
            leaves[PARALLELISM - 1].lastNode = true

            // Feed padded key block to each leaf (bypassing the sp-level buffer)
            if (key.isNotEmpty()) {
                val keyBlock = ByteArray(BLOCK_SIZE)
                key.copyInto(keyBlock)
                for (leaf in leaves) {
                    leaf.update(keyBlock, 0, BLOCK_SIZE)
                }
            }
        }

        public fun update(input: ByteArray): Hasher {
            update(input, 0, input.size)
            return this
        }

        private fun update(input: ByteArray, offset: Int, length: Int) {
            var pos = offset
            var remaining = length

            val left = bufLen
            val fill = SUPERBLOCK - left

            if (left != 0 && remaining >= fill) {
                input.copyInto(buf, left, pos, pos + fill)
                for (i in 0 until PARALLELISM) {
                    leaves[i].update(buf, i * BLOCK_SIZE, BLOCK_SIZE)
                }
                pos += fill
                remaining -= fill
                bufLen = 0
            }

            while (remaining >= SUPERBLOCK) {
                for (i in 0 until PARALLELISM) {
                    leaves[i].update(input, pos + i * BLOCK_SIZE, BLOCK_SIZE)
                }
                pos += SUPERBLOCK
                remaining -= SUPERBLOCK
            }

            if (remaining > 0) {
                input.copyInto(buf, bufLen, pos, pos + remaining)
                bufLen += remaining
            }
        }

        public fun finalize(): ByteArray {
            for (i in 0 until PARALLELISM) {
                val start = i * BLOCK_SIZE
                if (bufLen > start) {
                    val len = minOf(bufLen - start, BLOCK_SIZE)
                    leaves[i].update(buf, start, len)
                }
            }

            for (leaf in leaves) {
                root.update(leaf.finalize(), 0, DIGEST_LENGTH)
            }

            return root.finalize()
        }
    }
}
