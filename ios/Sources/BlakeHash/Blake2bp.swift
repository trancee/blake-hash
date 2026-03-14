import Foundation

/// BLAKE2bp: 4-way parallel BLAKE2b tree hash.
///
/// Distributes input across 4 BLAKE2b leaf instances (128-byte blocks,
/// round-robin), then hashes the concatenated 64-byte leaf digests
/// with a root BLAKE2b instance. Always produces 64-byte output.
public struct BLAKE2bp: Sendable {
    private init() {}

    private static let parallelism = 4
    private static let leafBlockSize = BLAKE2bVariant.blockSize  // 128
    private static let stripeSize = parallelism * leafBlockSize  // 512
    private static let digestLength = 64

    /// Hash input in one shot.
    public static func hash(_ input: Data, key: Data = Data()) -> Data {
        var hasher = Hasher(key: key)
        hasher.update(input)
        return hasher.finalize()
    }

    /// Incremental BLAKE2bp hasher for streaming input.
    public struct Hasher: Sendable {
        private var leaves: [BLAKE2b.Hasher]
        private var root: BLAKE2b.Hasher
        private var buffer: [UInt8]
        private var bufferLength: Int
        private var finalized: Bool

        public init(key: Data = Data()) {
            let keyBytes = [UInt8](key)
            precondition(keyBytes.count <= 64, "BLAKE2bp key must be at most 64 bytes")

            var leavesArr = [BLAKE2b.Hasher]()
            for i in 0..<BLAKE2bp.parallelism {
                leavesArr.append(BLAKE2b.Hasher(
                    digestLength: BLAKE2bp.digestLength,
                    key: keyBytes,
                    fanout: BLAKE2bp.parallelism,
                    depth: 2,
                    nodeOffset: UInt64(i),
                    nodeDepth: 0,
                    innerLength: BLAKE2bp.digestLength
                ))
            }
            self.leaves = leavesArr

            self.root = BLAKE2b.Hasher(
                digestLength: BLAKE2bp.digestLength,
                key: keyBytes,
                fanout: BLAKE2bp.parallelism,
                depth: 2,
                nodeOffset: 0,
                nodeDepth: 1,
                innerLength: BLAKE2bp.digestLength,
                feedKey: false
            )
            self.root.setLastNode()

            self.buffer = [UInt8](repeating: 0, count: BLAKE2bp.stripeSize)
            self.bufferLength = 0
            self.finalized = false
        }

        public mutating func update(_ input: Data) {
            updateBytes([UInt8](input))
        }

        private mutating func updateBytes(_ input: [UInt8]) {
            precondition(!finalized)
            var offset = 0
            var remaining = input.count

            if bufferLength > 0 {
                let toCopy = min(remaining, BLAKE2bp.stripeSize - bufferLength)
                buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                                       with: input[offset..<(offset + toCopy)])
                bufferLength += toCopy
                offset += toCopy
                remaining -= toCopy

                if bufferLength == BLAKE2bp.stripeSize && remaining > 0 {
                    distributeBuffer()
                    bufferLength = 0
                }
            }

            while remaining > BLAKE2bp.stripeSize {
                for i in 0..<BLAKE2bp.parallelism {
                    leaves[i].update(
                        input,
                        offset: offset + i * BLAKE2bp.leafBlockSize,
                        length: BLAKE2bp.leafBlockSize
                    )
                }
                offset += BLAKE2bp.stripeSize
                remaining -= BLAKE2bp.stripeSize
            }

            if remaining > 0 {
                buffer.replaceSubrange(0..<remaining,
                                       with: input[offset..<(offset + remaining)])
                bufferLength = remaining
            }
        }

        public mutating func finalize() -> Data {
            Data(finalizeBytes())
        }

        private mutating func finalizeBytes() -> [UInt8] {
            precondition(!finalized)
            finalized = true

            // Distribute remaining buffered data to leaves
            for i in 0..<BLAKE2bp.parallelism {
                let leafStart = i * BLAKE2bp.leafBlockSize
                if bufferLength > leafStart {
                    let leafBytes = min(bufferLength - leafStart, BLAKE2bp.leafBlockSize)
                    leaves[i].update(buffer, offset: leafStart, length: leafBytes)
                }
            }
            // Only the last leaf gets the last-node flag
            leaves[BLAKE2bp.parallelism - 1].setLastNode()

            // Finalize each leaf and feed digest to root
            for i in 0..<BLAKE2bp.parallelism {
                let leafHash = leaves[i].finalizeBytes()
                root.update(leafHash)
            }

            return root.finalizeBytes()
        }

        private mutating func distributeBuffer() {
            for i in 0..<BLAKE2bp.parallelism {
                leaves[i].update(
                    buffer,
                    offset: i * BLAKE2bp.leafBlockSize,
                    length: BLAKE2bp.leafBlockSize
                )
            }
        }
    }
}
