import Foundation
import Testing
@testable import BlakeHash

// MARK: - Codable types for upstream JSON formats

/// BLAKE2 KAT entry: {"hash":"blake2b","in":"hex","key":"hex","out":"hex"}
struct BLAKE2KatEntry: Codable, Sendable {
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
struct BLAKE3OfficialFile: Codable, Sendable {
    let key: String
    let context_string: String
    let cases: [BLAKE3OfficialCase]
}

struct BLAKE3OfficialCase: Codable, Sendable {
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

    static func toHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // BLAKE2 KAT vectors filtered by algorithm and keyed/unkeyed
    static let blake2Kat: [BLAKE2KatEntry] = {
        let decoder = JSONDecoder()
        return try! decoder.decode([BLAKE2KatEntry].self, from: loadData("blake2-kat.json"))
    }()

    static func blake2Vectors(algorithm: String, keyed: Bool) -> [BLAKE2KatEntry] {
        blake2Kat.filter { $0.hash == algorithm && (keyed ? !$0.key.isEmpty : $0.key.isEmpty) }
    }

    // BLAKE3 official vectors
    static let blake3File: BLAKE3OfficialFile = {
        let decoder = JSONDecoder()
        return try! decoder.decode(BLAKE3OfficialFile.self, from: loadData("blake3-official.json"))
    }()
}

// MARK: - BLAKE2b upstream KAT

@Suite("Upstream KAT — BLAKE2b")
struct BLAKE2bUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2b", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2b", keyed: true)

    @Test("BLAKE2b unkeyed", arguments: unkeyed)
    func unkeyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(BLAKE2b.hash(Data(input)))
        #expect(actual == v.out)
    }

    @Test("BLAKE2b keyed", arguments: keyed)
    func keyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(BLAKE2b.hash(Data(input), key: Data(key)))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE2s upstream KAT

@Suite("Upstream KAT — BLAKE2s")
struct BLAKE2sUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2s", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2s", keyed: true)

    @Test("BLAKE2s unkeyed", arguments: unkeyed)
    func unkeyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(BLAKE2s.hash(Data(input)))
        #expect(actual == v.out)
    }

    @Test("BLAKE2s keyed", arguments: keyed)
    func keyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(BLAKE2s.hash(Data(input), key: Data(key)))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE2bp upstream KAT

@Suite("Upstream KAT — BLAKE2bp")
struct BLAKE2bpUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2bp", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2bp", keyed: true)

    @Test("BLAKE2bp unkeyed", arguments: unkeyed)
    func unkeyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(BLAKE2bp.hash(Data(input)))
        #expect(actual == v.out)
    }

    @Test("BLAKE2bp keyed", arguments: keyed)
    func keyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(BLAKE2bp.hash(Data(input), key: Data(key)))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE2sp upstream KAT

@Suite("Upstream KAT — BLAKE2sp")
struct BLAKE2spUpstreamTests {
    static let unkeyed = UpstreamLoader.blake2Vectors(algorithm: "blake2sp", keyed: false)
    static let keyed   = UpstreamLoader.blake2Vectors(algorithm: "blake2sp", keyed: true)

    @Test("BLAKE2sp unkeyed", arguments: unkeyed)
    func unkeyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let actual = UpstreamLoader.toHex(BLAKE2sp.hash(Data(input)))
        #expect(actual == v.out)
    }

    @Test("BLAKE2sp keyed", arguments: keyed)
    func keyedVector(v: BLAKE2KatEntry) {
        let input = UpstreamLoader.hexToBytes(v.input)
        let key = UpstreamLoader.hexToBytes(v.key)
        let actual = UpstreamLoader.toHex(BLAKE2sp.hash(Data(input), key: Data(key)))
        #expect(actual == v.out)
    }
}

// MARK: - BLAKE3 upstream official vectors

@Suite("Upstream Official — BLAKE3")
struct BLAKE3UpstreamTests {
    static let file  = UpstreamLoader.blake3File
    static let key   = Array(file.key.utf8)
    static let ctx   = file.context_string
    static let cases = file.cases

    /// XOF output size used for upstream extended-output tests (bytes).
    private static let xofBytes = 64

    // Default-length hash (first 32 bytes of extended output)
    @Test("BLAKE3 hash", arguments: cases)
    func hashVector(v: BLAKE3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        let expected32 = String(v.hash.prefix(64))
        let actual = UpstreamLoader.toHex(BLAKE3.hash(Data(input)))
        #expect(actual == expected32)
    }

    // Default-length keyed hash
    @Test("BLAKE3 keyed_hash", arguments: cases)
    func keyedHashVector(v: BLAKE3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        let expected32 = String(v.keyed_hash.prefix(64))
        let actual = UpstreamLoader.toHex(BLAKE3.keyedHash(key: Data(Self.key), data: Data(input)))
        #expect(actual == expected32)
    }

    // Default-length derive_key
    @Test("BLAKE3 derive_key", arguments: cases)
    func deriveKeyVector(v: BLAKE3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        let expected32 = String(v.derive_key.prefix(64))
        let actual = UpstreamLoader.toHex(BLAKE3.deriveKey(context: Self.ctx, keyMaterial: Data(input)))
        #expect(actual == expected32)
    }

    // XOF: extended output for hash mode (prefix comparison)
    @Test("BLAKE3 XOF hash", arguments: cases)
    func xofHashVector(v: BLAKE3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        var hasher = BLAKE3.Hasher()
        hasher.update(Data(input))
        let out = hasher.finalizeXof(outputLength: Self.xofBytes)
        #expect(UpstreamLoader.toHex(out) == String(v.hash.prefix(Self.xofBytes * 2)))
    }

    // XOF: extended output for keyed_hash mode (prefix comparison)
    @Test("BLAKE3 XOF keyed_hash", arguments: cases)
    func xofKeyedHashVector(v: BLAKE3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        var hasher = BLAKE3.Hasher(key: Data(Self.key))
        hasher.update(Data(input))
        let out = hasher.finalizeXof(outputLength: Self.xofBytes)
        #expect(UpstreamLoader.toHex(out) == String(v.keyed_hash.prefix(Self.xofBytes * 2)))
    }

    // XOF: extended output for derive_key mode (prefix comparison)
    @Test("BLAKE3 XOF derive_key", arguments: cases)
    func xofDeriveKeyVector(v: BLAKE3OfficialCase) {
        let input = UpstreamLoader.blake3Input(v.input_len)
        var hasher = BLAKE3.Hasher.deriveKey(context: Self.ctx)
        hasher.update(Data(input))
        let out = hasher.finalizeXof(outputLength: Self.xofBytes)
        #expect(UpstreamLoader.toHex(out) == String(v.derive_key.prefix(Self.xofBytes * 2)))
    }
}
