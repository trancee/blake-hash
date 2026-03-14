import Foundation

/// BLAKE2s cryptographic hash function (RFC 7693).
///
/// 32-bit optimized variant with 10 rounds, supporting 1–32 byte output,
/// optional keyed hashing (up to 32-byte key), salt, and personalization.
public struct BLAKE2s: Sendable {
    private init() {}

    /// Hash input in one shot.
    public static func hash(
        _ input: Data,
        digestLength: Int = 32,
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

    /// Incremental BLAKE2s hasher for streaming input.
    public struct Hasher: Sendable {
        private var engine: BLAKE2Engine<BLAKE2sVariant>

        public init(
            digestLength: Int = 32,
            key: Data = Data(),
            salt: Data = Data(),
            personalization: Data = Data()
        ) {
            let keyBytes = [UInt8](key)
            let saltBytes = [UInt8](salt)
            let persBytes = [UInt8](personalization)
            precondition(digestLength >= 1 && digestLength <= 32, "BLAKE2s digest length must be 1–32")
            precondition(keyBytes.count <= 32, "BLAKE2s key must be at most 32 bytes")
            precondition(saltBytes.count <= 8, "BLAKE2s salt must be at most 8 bytes")
            precondition(persBytes.count <= 8, "BLAKE2s personalization must be at most 8 bytes")

            let h = blake2sInitializeState(
                digestLength: digestLength,
                keyLength: keyBytes.count,
                salt: saltBytes,
                personalization: persBytes
            )
            engine = BLAKE2Engine<BLAKE2sVariant>(h: h, digestLength: digestLength, key: keyBytes)
        }

        /// Internal init for tree mode (used by BLAKE2sp).
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
            engine = BLAKE2Engine<BLAKE2sVariant>(
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
