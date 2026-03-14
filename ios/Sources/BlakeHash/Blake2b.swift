import Foundation

/// BLAKE2b cryptographic hash function (RFC 7693).
///
/// 64-bit optimized variant with 12 rounds, supporting 1–64 byte output,
/// optional keyed hashing (up to 64-byte key), salt, and personalization.
public struct BLAKE2b: Sendable {
    private init() {}

    /// Hash input in one shot.
    public static func hash(
        _ input: Data,
        digestLength: Int = 64,
        key: Data = Data(),
        salt: Data = Data(),
        personalization: Data = Data()
    ) -> Data {
        var hasher = Hasher(
            digestLength: digestLength, key: key,
            salt: salt, personalization: personalization
        )
        hasher.update(input)
        return hasher.finalize()
    }

    /// Incremental BLAKE2b hasher for streaming input.
    public struct Hasher: Sendable {
        private var engine: BLAKE2Engine<BLAKE2bVariant>

        public init(
            digestLength: Int = 64,
            key: Data = Data(),
            salt: Data = Data(),
            personalization: Data = Data()
        ) {
            let keyBytes = [UInt8](key)
            let saltBytes = [UInt8](salt)
            let persBytes = [UInt8](personalization)
            precondition(digestLength >= 1 && digestLength <= 64, "BLAKE2b digest length must be 1–64")
            precondition(keyBytes.count <= 64, "BLAKE2b key must be at most 64 bytes")
            precondition(saltBytes.count <= 16, "BLAKE2b salt must be at most 16 bytes")
            precondition(persBytes.count <= 16, "BLAKE2b personalization must be at most 16 bytes")

            let h = blake2bInitializeState(
                digestLength: digestLength,
                keyLength: keyBytes.count,
                salt: saltBytes,
                personalization: persBytes
            )
            engine = BLAKE2Engine<BLAKE2bVariant>(h: h, digestLength: digestLength, key: keyBytes)
        }

        /// Internal init for tree mode (used by BLAKE2bp).
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
            let h = blake2bInitializeState(
                digestLength: digestLength,
                keyLength: key.count,
                fanout: fanout,
                depth: depth,
                nodeOffset: nodeOffset,
                nodeDepth: nodeDepth,
                innerLength: innerLength
            )
            engine = BLAKE2Engine<BLAKE2bVariant>(
                h: h, digestLength: digestLength,
                key: feedKey ? key : []
            )
        }

        public mutating func update(_ input: Data) {
            engine.update([UInt8](input))
        }

        internal mutating func update(_ input: [UInt8]) {
            engine.update(input)
        }

        internal mutating func update(_ input: [UInt8], offset: Int, length: Int) {
            engine.update(input, offset: offset, length: length)
        }

        /// Set the last-node flag (for tree mode finalization).
        internal mutating func setLastNode() {
            engine.isLastNode = true
        }

        public mutating func finalize() -> Data {
            Data(engine.finalize())
        }

        internal mutating func finalizeBytes() -> [UInt8] {
            engine.finalize()
        }
    }
}
