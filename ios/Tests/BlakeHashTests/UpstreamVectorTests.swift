import Foundation
import Testing
@testable import BlakeHash

// MARK: - Codable types for upstream JSON formats

/// BLAKE2 KAT entry: {"hash":"blake2b","in":"hex","key":"hex","out":"hex"}
struct Blake2KatEntry: Codable, Sendable {
    let hash: String
    let input: String
    let key: String
    let out: String

    enum CodingKeys: String, CodingKey {
        case hash
        case input = "in"
        case key
        case out
    }
}

/// BLAKE3 official case: {"input_len":N,"hash":"hex","keyed_hash":"hex","derive_key":"hex"}
struct Blake3OfficialFile: Codable, Sendable {
    let key: String
    let context_string: String
    let cases: [Blake3OfficialCase]
}

struct Blake3OfficialCase: Codable, Sendable {
    let input_len: Int
    let hash: String
    let keyed_hash: String
    let derive_key: String
}

// MARK: - Upstream vector loader

private enum UpstreamLoader {
    static let vectorsDir: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent() // BlakeHashTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // repo root
        return repoRoot.appendingPathComponent("test-vectors").appendingPathComponent("upstream")
    }()

    static func loadData(_ filename: String) -> Data {
        let url = vectorsDir.appendingPathComponent(filename)
        return try! Data(contentsOf: url)
    }

    static func hexToBytes(_ hex: String) -> [UInt8] {
        var bytes = [UInt8]()
        var i = hex.startIndex
        while i < hex.endIndex {
            let next = hex.index(i, offsetBy: 2)
            bytes.append(UInt8(hex[i..<next], radix: 16)!)
            i = next
        }
        return bytes
    }

    static func blake3Input(_ n: Int) -> [UInt8] {
        (0..<n).map { UInt8($0 % 251) }
    }

    static func toHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    // BLAKE2 KAT vectors filtered by algorithm and keyed/unkeyed
    static let blake2Kat: [Blake2KatEntry] = {
        let decoder = JSONDecoder()
        return try! decoder.decode([Blake2KatEntry].self, from: loadData("blake2-kat.json"))
    }()

    static func blake2Vectors(algorithm: String, keyed: Bool) -> [Blake2KatEntry] {
        blake2Kat.filter { $0.hash == algorithm && (keyed ? !$0.key.isEmpty : $0.key.isEmpty) }
    }

    // BLAKE3 official vectors
    static let blake3File: Blake3OfficialFile = {
        let decoder = JSONDecoder()
        return try! decoder.decode(Blake3OfficialFile.self, from: loadData("blake3-official.json"))
    }()
}

// MARK: - BLAKE2b upstream KAT

@Suite("Upstream KAT — BLAKE2b")
struct Blake2bUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2b", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2b", keyed: true)

    @Test("BLAKE2b unkeyed", arguments: unkeyed)
    func unkeyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(Blake2b.hash(input))
        #expect(actual == v.out)
    }

    @Test("BLAKE2b keyed", arguments: keyed)
    func keyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(Blake2b.hash(input, key: key))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE2s upstream KAT

@Suite("Upstream KAT — BLAKE2s")
struct Blake2sUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2s", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2s", keyed: true)

    @Test("BLAKE2s unkeyed", arguments: unkeyed)
    func unkeyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(Blake2s.hash(input))
        #expect(actual == v.out)
    }

    @Test("BLAKE2s keyed", arguments: keyed)
    func keyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(Blake2s.hash(input, key: key))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE2bp upstream KAT

@Suite("Upstream KAT — BLAKE2bp")
struct Blake2bpUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2bp", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2bp", keyed: true)

    @Test("BLAKE2bp unkeyed", arguments: unkeyed)
    func unkeyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(Blake2bp.hash(input))
        #expect(actual == v.out)
    }

    @Test("BLAKE2bp keyed", arguments: keyed)
    func keyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(Blake2bp.hash(input, key: key))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE2sp upstream KAT

@Suite("Upstream KAT — BLAKE2sp")
struct Blake2spUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2sp", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2sp", keyed: true)

    @Test("BLAKE2sp unkeyed", arguments: unkeyed)
    func unkeyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(Blake2sp.hash(input))
        #expect(actual == v.out)
    }

    @Test("BLAKE2sp keyed", arguments: keyed)
    func keyedVector(v: Blake2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(Blake2sp.hash(input, key: key))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE3 upstream official vectors

@Suite("Upstream Official — BLAKE3")
struct Blake3UpstreamTests {
    static let file  = UpstreamLoader.blake3File
    static let key   = Array(file.key.utf8)
    static let ctx   = file.context_string
    static let cases = file.cases

    /// XOF output size used for upstream extended-output tests (bytes).
    private static let xofBytes = 64

    // Default-length hash (first 32 bytes of extended output)
    @Test("BLAKE3 hash", arguments: cases)
    func hashVector(v: Blake3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        let expected32 = String(v.hash.prefix(64))
        let actual = UpstreamLoader.toHex(Blake3.hash(input))
        #expect(actual == expected32)
    }

    // Default-length keyed hash
    @Test("BLAKE3 keyed_hash", arguments: cases)
    func keyedHashVector(v: Blake3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        let expected32 = String(v.keyed_hash.prefix(64))
        let actual = UpstreamLoader.toHex(Blake3.keyedHash(key: Self.key, data: input))
        #expect(actual == expected32)
    }

    // Default-length derive_key
    @Test("BLAKE3 derive_key", arguments: cases)
    func deriveKeyVector(v: Blake3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        let expected32 = String(v.derive_key.prefix(64))
        let actual = UpstreamLoader.toHex(Blake3.deriveKey(context: Self.ctx, keyMaterial: input))
        #expect(actual == expected32)
    }

    // XOF: extended output for hash mode (prefix comparison)
    @Test("BLAKE3 XOF hash", arguments: cases)
    func xofHashVector(v: Blake3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        var hasher = Blake3.Hasher()
        hasher.update(input)
        let out = hasher.finalizeXof(outputLength: Self.xofBytes)
        #expect(UpstreamLoader.toHex(out) == String(v.hash.prefix(Self.xofBytes * 2)))
    }

    // XOF: extended output for keyed_hash mode (prefix comparison)
    @Test("BLAKE3 XOF keyed_hash", arguments: cases)
    func xofKeyedHashVector(v: Blake3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        var hasher = Blake3.Hasher(key: Self.key)
        hasher.update(input)
        let out = hasher.finalizeXof(outputLength: Self.xofBytes)
        #expect(UpstreamLoader.toHex(out) == String(v.keyed_hash.prefix(Self.xofBytes * 2)))
    }

    // XOF: extended output for derive_key mode (prefix comparison)
    @Test("BLAKE3 XOF derive_key", arguments: cases)
    func xofDeriveKeyVector(v: Blake3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        var hasher = Blake3.Hasher.deriveKey(context: Self.ctx)
        hasher.update(input)
        let out = hasher.finalizeXof(outputLength: Self.xofBytes)
        #expect(UpstreamLoader.toHex(out) == String(v.derive_key.prefix(Self.xofBytes * 2)))
    }
}
