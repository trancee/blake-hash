import Foundation

/// BLAKE2sp: 8-way parallel BLAKE2s tree hash.
///
/// Distributes input across 8 BLAKE2s leaf instances (64-byte blocks,
/// round-robin), then hashes the concatenated 32-byte leaf digests
/// with a root BLAKE2s instance. Always produces 32-byte output.
public struct BLAKE2sp: Sendable {
    private init() {}

    private static let parallelism = 8
    private static let leafBlockSize = BLAKE2sVariant.blockSize  // 64
    private static let stripeSize = parallelism * leafBlockSize  // 512
    private static let digestLength = 32

    /// Hash input in one shot.
    public static func hash(_ input: Data, key: Data = Data()) -> Data {
        var hasher = Hasher(key: key)
        hasher.update(input)
        return hasher.finalize()
    }

    /// Incremental BLAKE2sp hasher for streaming input.
    public struct Hasher: Sendable {
        private var leaves: [BLAKE2s.Hasher]
        private var root: BLAKE2s.Hasher
        private var buffer: [UInt8]
        private var bufferLength: Int
        private var finalized: Bool

        public init(key: Data = Data()) {
            let keyBytes = [UInt8](key)
            precondition(keyBytes.count <= 32, "BLAKE2sp key must be at most 32 bytes")

            var leavesArr = [BLAKE2s.Hasher]()
            for i in 0..<BLAKE2sp.parallelism {
                leavesArr.append(BLAKE2s.Hasher(
                    digestLength: BLAKE2sp.digestLength,
                    key: keyBytes,
                    fanout: BLAKE2sp.parallelism,
                    depth: 2,
                    nodeOffset: UInt64(i),
                    nodeDepth: 0,
                    innerLength: BLAKE2sp.digestLength
                ))
            }
            self.leaves = leavesArr

            self.root = BLAKE2s.Hasher(
                digestLength: BLAKE2sp.digestLength,
                key: keyBytes,
                fanout: BLAKE2sp.parallelism,
                depth: 2,
                nodeOffset: 0,
                nodeDepth: 1,
                innerLength: BLAKE2sp.digestLength,
                feedKey: false
            )
            self.root.setLastNode()

            self.buffer = [UInt8](repeating: 0, count: BLAKE2sp.stripeSize)
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
                let toCopy = min(remaining, BLAKE2sp.stripeSize - bufferLength)
                buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                                       with: input[offset..<(offset + toCopy)])
                bufferLength += toCopy
                offset += toCopy
                remaining -= toCopy

                if bufferLength == BLAKE2sp.stripeSize && remaining > 0 {
                    distributeBuffer()
                    bufferLength = 0
                }
            }

            while remaining > BLAKE2sp.stripeSize {
                for i in 0..<BLAKE2sp.parallelism {
                    leaves[i].update(
                        input,
                        offset: offset + i * BLAKE2sp.leafBlockSize,
                        length: BLAKE2sp.leafBlockSize
                    )
                }
                offset += BLAKE2sp.stripeSize
                remaining -= BLAKE2sp.stripeSize
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
            for i in 0..<BLAKE2sp.parallelism {
                let leafStart = i * BLAKE2sp.leafBlockSize
                if bufferLength > leafStart {
                    let leafBytes = min(bufferLength - leafStart, BLAKE2sp.leafBlockSize)
                    leaves[i].update(buffer, offset: leafStart, length: leafBytes)
                }
            }
            // Only the last leaf gets the last-node flag
            leaves[BLAKE2sp.parallelism - 1].setLastNode()

            // Finalize each leaf and feed digest to root
            for i in 0..<BLAKE2sp.parallelism {
                let leafHash = leaves[i].finalizeBytes()
                root.update(leafHash)
            }

            return root.finalizeBytes()
        }

        private mutating func distributeBuffer() {
            for i in 0..<BLAKE2sp.parallelism {
                leaves[i].update(
                    buffer,
                    offset: i * BLAKE2sp.leafBlockSize,
                    length: BLAKE2sp.leafBlockSize
                )
            }
        }
    }
}
