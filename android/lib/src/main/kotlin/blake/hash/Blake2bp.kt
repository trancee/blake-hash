package blake.hash

/**
 * BLAKE2bp – 4-way parallel BLAKE2b.
 *
 * Produces a 64-byte digest. Input is distributed across 4 leaf BLAKE2b
 * instances in round-robin 128-byte blocks; the 4 leaf digests are then
 * hashed by a single root BLAKE2b to produce the final output.
 */
public class BLAKE2bp private constructor() {

    public companion object {
        private const val PARALLELISM = 4
        private const val BLOCK_SIZE = BLAKE2bEngine.BLOCK_SIZE       // 128
        private const val DIGEST_LENGTH = BLAKE2bEngine.MAX_DIGEST    // 64
        private const val SUPERBLOCK = PARALLELISM * BLOCK_SIZE       // 512

        /**
         * One-shot hash: returns the 64-byte BLAKE2bp digest of [input].
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
     * Incremental BLAKE2bp hasher for streaming data.
     */
    public class Hasher @JvmOverloads public constructor(
        key: ByteArray = ByteArray(0)
    ) {
        private val leaves: Array<BLAKE2bEngine>
        private val root: BLAKE2bEngine
        private val buf = ByteArray(SUPERBLOCK)
        private var bufLen = 0

        init {
            val keyLen = key.size

            // Root first (reference order)
            root = BLAKE2bEngine(
                digestLength = DIGEST_LENGTH,
                fanout = PARALLELISM,
                depth = 2,
                leafLength = 0,
                nodeOffset = 0,
                nodeDepth = 1,
                innerLength = DIGEST_LENGTH,
                paramKeyLength = keyLen
            )

            // Create 4 leaf engines (node_offset = 0..3)
            leaves = Array(PARALLELISM) { i ->
                BLAKE2bEngine(
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

            // Feed padded key block to each leaf (bypassing the bp-level buffer)
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
            // Distribute remaining buffered data to leaves
            for (i in 0 until PARALLELISM) {
                val start = i * BLOCK_SIZE
                if (bufLen > start) {
                    val len = minOf(bufLen - start, BLOCK_SIZE)
                    leaves[i].update(buf, start, len)
                }
            }

            // Finalize all leaves, feed digests to root
            for (leaf in leaves) {
                root.update(leaf.finalize(), 0, DIGEST_LENGTH)
            }

            return root.finalize()
        }
    }
}
