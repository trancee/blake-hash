/// BLAKE3 cryptographic hash function — public API.
/// Pure Swift implementation with zero external dependencies.
public struct Blake3: Sendable {

    // MARK: - Convenience functions

    /// Hash the input with BLAKE3 (32-byte output).
    public static func hash(_ input: [UInt8]) -> [UInt8] {
        var hasher = Hasher()
        hasher.update(input)
        return hasher.finalize()
    }

    /// Keyed hash (MAC/PRF). Key must be exactly 32 bytes.
    public static func keyedHash(key: [UInt8], data: [UInt8]) -> [UInt8] {
        var hasher = Hasher(key: key)
        hasher.update(data)
        return hasher.finalize()
    }

    /// Derive a 32-byte key from context string and key material.
    public static func deriveKey(context: String, keyMaterial: [UInt8]) -> [UInt8] {
        var hasher = Hasher.deriveKey(context: context)
        hasher.update(keyMaterial)
        return hasher.finalize()
    }

    // MARK: - Incremental Hasher

    public struct Hasher: Sendable {
        private var engine: Blake3Engine

        /// Hash mode (unkeyed).
        public init() {
            engine = Blake3Engine(key: Blake3Constants.IV, flags: 0)
        }

        /// Keyed hash mode. Key must be exactly 32 bytes.
        public init(key: [UInt8]) {
            precondition(key.count == 32, "BLAKE3 keyed hash requires a 32-byte key")
            let keyWords = wordsFromBytes(key)
            engine = Blake3Engine(key: keyWords, flags: Blake3Constants.KEYED_HASH)
        }

        /// Internal init for derive_key phase 2.
        private init(derivedKey: [UInt32]) {
            engine = Blake3Engine(key: derivedKey, flags: Blake3Constants.DERIVE_KEY_MATERIAL)
        }

        /// Create a derive_key hasher.
        public static func deriveKey(context: String) -> Hasher {
            // Phase 1: hash the context string with DERIVE_KEY_CONTEXT
            let contextBytes = Array(context.utf8)
            var contextHasher = Blake3Engine(
                key: Blake3Constants.IV,
                flags: Blake3Constants.DERIVE_KEY_CONTEXT
            )
            contextHasher.update(contextBytes)
            let contextOutput = contextHasher.finalOutput()
            // Use first 8 words (32 bytes) of root output as the derived key
            let contextKeyBytes = contextOutput.rootOutputBytes(outputLength: Blake3Constants.KEY_LEN)
            let contextKey = wordsFromBytes(contextKeyBytes)

            // Phase 2: the returned hasher uses DERIVE_KEY_MATERIAL
            return Hasher(derivedKey: contextKey)
        }

        /// Feed input data incrementally.
        public mutating func update(_ input: [UInt8]) {
            engine.update(input)
        }

        /// Finalize with default 32-byte output.
        public func finalize() -> [UInt8] {
            finalizeXof(outputLength: Blake3Constants.OUT_LEN)
        }

        /// Finalize with arbitrary output length (XOF).
        public func finalizeXof(outputLength: Int) -> [UInt8] {
            engine.finalOutput().rootOutputBytes(outputLength: outputLength)
        }
    }
}
