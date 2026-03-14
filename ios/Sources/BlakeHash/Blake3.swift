import Foundation

/// BLAKE3 cryptographic hash function — public API.
/// Pure Swift implementation with zero external dependencies.
public struct BLAKE3: Sendable {

    // MARK: - Convenience functions

    /// Hash the input with BLAKE3 (32-byte output).
    public static func hash(_ input: Data) -> Data {
        var hasher = Hasher()
        hasher.update(input)
        return hasher.finalize()
    }

    /// Keyed hash (MAC/PRF). Key must be exactly 32 bytes.
    public static func keyedHash(key: Data, data: Data) -> Data {
        var hasher = Hasher(key: key)
        hasher.update(data)
        return hasher.finalize()
    }

    /// Derive a 32-byte key from context string and key material.
    public static func deriveKey(context: String, keyMaterial: Data) -> Data {
        var hasher = Hasher.deriveKey(context: context)
        hasher.update(keyMaterial)
        return hasher.finalize()
    }

    // MARK: - Incremental Hasher

    public struct Hasher: Sendable {
        private var engine: BLAKE3Engine

        /// Hash mode (unkeyed).
        public init() {
            engine = BLAKE3Engine(key: BLAKE3Constants.IV, flags: 0)
        }

        /// Keyed hash mode. Key must be exactly 32 bytes.
        public init(key: Data) {
            let keyBytes = [UInt8](key)
            precondition(keyBytes.count == 32, "BLAKE3 keyed hash requires a 32-byte key")
            let keyWords = wordsFromBytes(keyBytes)
            engine = BLAKE3Engine(key: keyWords, flags: BLAKE3Constants.KEYED_HASH)
        }

        /// Internal init for derive_key phase 2.
        private init(derivedKey: [UInt32]) {
            engine = BLAKE3Engine(key: derivedKey, flags: BLAKE3Constants.DERIVE_KEY_MATERIAL)
        }

        /// Create a derive_key hasher.
        public static func deriveKey(context: String) -> Hasher {
            // Phase 1: hash the context string with DERIVE_KEY_CONTEXT
            let contextBytes = Array(context.utf8)
            var contextHasher = BLAKE3Engine(
                key: BLAKE3Constants.IV,
                flags: BLAKE3Constants.DERIVE_KEY_CONTEXT
            )
            contextHasher.update(contextBytes)
            let contextOutput = contextHasher.finalOutput()
            // Use first 8 words (32 bytes) of root output as the derived key
            let contextKeyBytes = contextOutput.rootOutputBytes(outputLength: BLAKE3Constants.KEY_LEN)
            let contextKey = wordsFromBytes(contextKeyBytes)

            // Phase 2: the returned hasher uses DERIVE_KEY_MATERIAL
            return Hasher(derivedKey: contextKey)
        }

        /// Feed input data incrementally.
        public mutating func update(_ input: Data) {
            engine.update([UInt8](input))
        }

        /// Finalize with default 32-byte output.
        public func finalize() -> Data {
            Data(engine.finalOutput().rootOutputBytes(outputLength: BLAKE3Constants.OUT_LEN))
        }

        /// Finalize with arbitrary output length (XOF).
        public func finalizeXof(outputLength: Int) -> Data {
            Data(engine.finalOutput().rootOutputBytes(outputLength: outputLength))
        }
    }
}
