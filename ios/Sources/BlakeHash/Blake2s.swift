/// BLAKE2s cryptographic hash function (RFC 7693).
///
/// 32-bit optimized variant with 10 rounds, supporting 1–32 byte output,
/// optional keyed hashing (up to 32-byte key), salt, and personalization.
public struct Blake2s: Sendable {
    private init() {}

    /// Hash input in one shot.
    public static func hash(
        _ input: [UInt8],
        digestLength: Int = 32,
        key: [UInt8] = [],
        salt: [UInt8] = [],
        personalization: [UInt8] = []
    ) -> [UInt8] {
        var hasher = Hasher(
            digestLength: digestLength, key: key,
            salt: salt, personalization: personalization
        )
        hasher.update(input)
        return hasher.finalize()
    }

    /// Incremental BLAKE2s hasher for streaming input.
    public struct Hasher: Sendable {
        private var engine: Blake2Engine<Blake2sVariant>

        public init(
            digestLength: Int = 32,
            key: [UInt8] = [],
            salt: [UInt8] = [],
            personalization: [UInt8] = []
        ) {
            precondition(digestLength >= 1 && digestLength <= 32, "BLAKE2s digest length must be 1–32")
            precondition(key.count <= 32, "BLAKE2s key must be at most 32 bytes")
            precondition(salt.count <= 8, "BLAKE2s salt must be at most 8 bytes")
            precondition(personalization.count <= 8, "BLAKE2s personalization must be at most 8 bytes")

            let h = blake2sInitializeState(
                digestLength: digestLength,
                keyLength: key.count,
                salt: salt,
                personalization: personalization
            )
            engine = Blake2Engine<Blake2sVariant>(h: h, digestLength: digestLength, key: key)
        }

        /// Internal init for tree mode (used by Blake2sp).
        internal init(
            digestLength: Int,
            key: [UInt8],
            fanout: Int,
            depth: Int,
            nodeOffset: UInt64,
            nodeDepth: Int,
            innerLength: Int,
            feedKey: Bool = true
        ) {
            let h = blake2sInitializeState(
                digestLength: digestLength,
                keyLength: key.count,
                fanout: fanout,
                depth: depth,
                nodeOffset: nodeOffset,
                nodeDepth: nodeDepth,
                innerLength: innerLength
            )
            engine = Blake2Engine<Blake2sVariant>(
                h: h, digestLength: digestLength,
                key: feedKey ? key : []
            )
        }

        public mutating func update(_ input: [UInt8]) {
            engine.update(input)
        }

        public mutating func update(_ input: [UInt8], offset: Int, length: Int) {
            engine.update(input, offset: offset, length: length)
        }

        /// Set the last-node flag (for tree mode finalization).
        internal mutating func setLastNode() {
            engine.isLastNode = true
        }

        public mutating func finalize() -> [UInt8] {
            engine.finalize()
        }
    }
}
