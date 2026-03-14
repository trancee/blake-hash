/// BLAKE2bp: 4-way parallel BLAKE2b tree hash.
///
/// Distributes input across 4 BLAKE2b leaf instances (128-byte blocks,
/// round-robin), then hashes the concatenated 64-byte leaf digests
/// with a root BLAKE2b instance. Always produces 64-byte output.
public struct Blake2bp: Sendable {
    private init() {}

    private static let parallelism = 4
    private static let leafBlockSize = Blake2bVariant.blockSize  // 128
    private static let stripeSize = parallelism * leafBlockSize  // 512
    private static let digestLength = 64

    /// Hash input in one shot.
    public static func hash(_ input: [UInt8], key: [UInt8] = []) -> [UInt8] {
        var hasher = Hasher(key: key)
        hasher.update(input)
        return hasher.finalize()
    }

    /// Incremental BLAKE2bp hasher for streaming input.
    public struct Hasher: Sendable {
        private var leaves: [Blake2b.Hasher]
        private var root: Blake2b.Hasher
        private var buffer: [UInt8]
        private var bufferLength: Int
        private var finalized: Bool

        public init(key: [UInt8] = []) {
            precondition(key.count <= 64, "BLAKE2bp key must be at most 64 bytes")

            var leavesArr = [Blake2b.Hasher]()
            for i in 0..<Blake2bp.parallelism {
                leavesArr.append(Blake2b.Hasher(
                    digestLength: Blake2bp.digestLength,
                    key: key,
                    fanout: Blake2bp.parallelism,
                    depth: 2,
                    nodeOffset: UInt64(i),
                    nodeDepth: 0,
                    innerLength: Blake2bp.digestLength
                ))
            }
            self.leaves = leavesArr

            self.root = Blake2b.Hasher(
                digestLength: Blake2bp.digestLength,
                key: key,
                fanout: Blake2bp.parallelism,
                depth: 2,
                nodeOffset: 0,
                nodeDepth: 1,
                innerLength: Blake2bp.digestLength,
                feedKey: false
            )
            self.root.setLastNode()

            self.buffer = [UInt8](repeating: 0, count: Blake2bp.stripeSize)
            self.bufferLength = 0
            self.finalized = false
        }

        public mutating func update(_ input: [UInt8]) {
            precondition(!finalized)
            var offset = 0
            var remaining = input.count

            if bufferLength > 0 {
                let toCopy = min(remaining, Blake2bp.stripeSize - bufferLength)
                buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                                       with: input[offset..<(offset + toCopy)])
                bufferLength += toCopy
                offset += toCopy
                remaining -= toCopy

                if bufferLength == Blake2bp.stripeSize && remaining > 0 {
                    distributeBuffer()
                    bufferLength = 0
                }
            }

            while remaining > Blake2bp.stripeSize {
                for i in 0..<Blake2bp.parallelism {
                    leaves[i].update(
                        input,
                        offset: offset + i * Blake2bp.leafBlockSize,
                        length: Blake2bp.leafBlockSize
                    )
                }
                offset += Blake2bp.stripeSize
                remaining -= Blake2bp.stripeSize
            }

            if remaining > 0 {
                buffer.replaceSubrange(0..<remaining,
                                       with: input[offset..<(offset + remaining)])
                bufferLength = remaining
            }
        }

        public mutating func finalize() -> [UInt8] {
            precondition(!finalized)
            finalized = true

            // Distribute remaining buffered data to leaves
            for i in 0..<Blake2bp.parallelism {
                let leafStart = i * Blake2bp.leafBlockSize
                if bufferLength > leafStart {
                    let leafBytes = min(bufferLength - leafStart, Blake2bp.leafBlockSize)
                    leaves[i].update(buffer, offset: leafStart, length: leafBytes)
                }
            }
            // Only the last leaf gets the last-node flag
            leaves[Blake2bp.parallelism - 1].setLastNode()

            // Finalize each leaf and feed digest to root
            for i in 0..<Blake2bp.parallelism {
                let leafHash = leaves[i].finalize()
                root.update(leafHash)
            }

            return root.finalize()
        }

        private mutating func distributeBuffer() {
            for i in 0..<Blake2bp.parallelism {
                leaves[i].update(
                    buffer,
                    offset: i * Blake2bp.leafBlockSize,
                    length: Blake2bp.leafBlockSize
                )
            }
        }
    }
}
