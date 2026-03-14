/// BLAKE2sp: 8-way parallel BLAKE2s tree hash.
///
/// Distributes input across 8 BLAKE2s leaf instances (64-byte blocks,
/// round-robin), then hashes the concatenated 32-byte leaf digests
/// with a root BLAKE2s instance. Always produces 32-byte output.
public struct Blake2sp: Sendable {
    private init() {}

    private static let parallelism = 8
    private static let leafBlockSize = Blake2sVariant.blockSize  // 64
    private static let stripeSize = parallelism * leafBlockSize  // 512
    private static let digestLength = 32

    /// Hash input in one shot.
    public static func hash(_ input: [UInt8], key: [UInt8] = []) -> [UInt8] {
        var hasher = Hasher(key: key)
        hasher.update(input)
        return hasher.finalize()
    }

    /// Incremental BLAKE2sp hasher for streaming input.
    public struct Hasher: Sendable {
        private var leaves: [Blake2s.Hasher]
        private var root: Blake2s.Hasher
        private var buffer: [UInt8]
        private var bufferLength: Int
        private var finalized: Bool

        public init(key: [UInt8] = []) {
            precondition(key.count <= 32, "BLAKE2sp key must be at most 32 bytes")

            var leavesArr = [Blake2s.Hasher]()
            for i in 0..<Blake2sp.parallelism {
                leavesArr.append(Blake2s.Hasher(
                    digestLength: Blake2sp.digestLength,
                    key: key,
                    fanout: Blake2sp.parallelism,
                    depth: 2,
                    nodeOffset: UInt64(i),
                    nodeDepth: 0,
                    innerLength: Blake2sp.digestLength
                ))
            }
            self.leaves = leavesArr

            self.root = Blake2s.Hasher(
                digestLength: Blake2sp.digestLength,
                key: key,
                fanout: Blake2sp.parallelism,
                depth: 2,
                nodeOffset: 0,
                nodeDepth: 1,
                innerLength: Blake2sp.digestLength,
                feedKey: false
            )
            self.root.setLastNode()

            self.buffer = [UInt8](repeating: 0, count: Blake2sp.stripeSize)
            self.bufferLength = 0
            self.finalized = false
        }

        public mutating func update(_ input: [UInt8]) {
            precondition(!finalized)
            var offset = 0
            var remaining = input.count

            if bufferLength > 0 {
                let toCopy = min(remaining, Blake2sp.stripeSize - bufferLength)
                buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                                       with: input[offset..<(offset + toCopy)])
                bufferLength += toCopy
                offset += toCopy
                remaining -= toCopy

                if bufferLength == Blake2sp.stripeSize && remaining > 0 {
                    distributeBuffer()
                    bufferLength = 0
                }
            }

            while remaining > Blake2sp.stripeSize {
                for i in 0..<Blake2sp.parallelism {
                    leaves[i].update(
                        input,
                        offset: offset + i * Blake2sp.leafBlockSize,
                        length: Blake2sp.leafBlockSize
                    )
                }
                offset += Blake2sp.stripeSize
                remaining -= Blake2sp.stripeSize
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
            for i in 0..<Blake2sp.parallelism {
                let leafStart = i * Blake2sp.leafBlockSize
                if bufferLength > leafStart {
                    let leafBytes = min(bufferLength - leafStart, Blake2sp.leafBlockSize)
                    leaves[i].update(buffer, offset: leafStart, length: leafBytes)
                }
            }
            // Only the last leaf gets the last-node flag
            leaves[Blake2sp.parallelism - 1].setLastNode()

            // Finalize each leaf and feed digest to root
            for i in 0..<Blake2sp.parallelism {
                let leafHash = leaves[i].finalize()
                root.update(leafHash)
            }

            return root.finalize()
        }

        private mutating func distributeBuffer() {
            for i in 0..<Blake2sp.parallelism {
                leaves[i].update(
                    buffer,
                    offset: i * Blake2sp.leafBlockSize,
                    length: Blake2sp.leafBlockSize
                )
            }
        }
    }
}
