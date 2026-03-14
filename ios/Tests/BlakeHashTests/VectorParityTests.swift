import Foundation
import Testing
@testable import BlakeHash

// MARK: - Sendable vector types (parsed from shared JSON)

struct HashVector: Codable, Sendable {
    let input: String?
    let inputHex: String?
    let sequentialLength: Int?
    let inputLength: Int?
    let digestBytes: Int?
    let outputBytes: Int?
    let expected: String
}

struct KeyedSection: Codable, Sendable {
    let keyHex: String
    let vectors: [HashVector]
}

struct SaltPersVector: Codable, Sendable {
    let input: String
    let digestBytes: Int
    let salt: String
    let personalization: String
    let expected: String
}

struct BLAKE2File: Codable, Sendable {
    let hash: [HashVector]
    let keyed: KeyedSection
    let saltPersonalization: [SaltPersVector]?
}

struct BLAKE2ParallelFile: Codable, Sendable {
    let hash: [HashVector]
    let keyed: KeyedSection
}

struct BLAKE3HashSection: Codable, Sendable {
    let named: [HashVector]
    let sequential: [HashVector]
}

struct BLAKE3XofSection: Codable, Sendable {
    let hash: [HashVector]
    let keyed: [HashVector]
    let deriveKey: [HashVector]
}

struct BLAKE3File: Codable, Sendable {
    let keyHex: String
    let deriveKeyContext: String
    let hash: BLAKE3HashSection
    let keyedHash: [HashVector]
    let deriveKey: [HashVector]
    let xof: BLAKE3XofSection
}

// MARK: - Vector loader

private enum VectorLoader {
    static let vectorsDir: URL = {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent() // BlakeHashTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // repo root
        return repoRoot.appendingPathComponent("test-vectors")
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

    static func sequentialBytes(_ n: Int) -> [UInt8] {
        (0..<n).map { UInt8($0 % 256) }
    }

    static func blake3Input(_ n: Int) -> [UInt8] {
        (0..<n).map { UInt8($0 % 251) }
    }

    static func resolveInput(_ v: HashVector, blake3: Bool = false) -> [UInt8] {
        if let s = v.input { return Array(s.utf8) }
        if let hex = v.inputHex { return hexToBytes(hex) }
        if let n = v.sequentialLength { return sequentialBytes(n) }
        if let n = v.inputLength { return blake3 ? blake3Input(n) : sequentialBytes(n) }
        fatalError("Vector has no input field")
    }

    static func toHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func toHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - BLAKE2b vector parity

@Suite("Vector Parity — BLAKE2b")
struct BLAKE2bVectorParityTests {
    static let file: BLAKE2File = {
        let decoder = JSONDecoder()
        return try! decoder.decode(BLAKE2File.self, from: VectorLoader.loadData("blake2b.json"))
    }()

    @Test("BLAKE2b hash", arguments: file.hash)
    func hashVector(v: HashVector) {
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2b.hash(Data(input), digestLength: v.digestBytes!))
        #expect(actual == v.expected)
    }

    @Test("BLAKE2b keyed", arguments: file.keyed.vectors)
    func keyedVector(v: HashVector) {
        let key = VectorLoader.hexToBytes(Self.file.keyed.keyHex)
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2b.hash(Data(input), digestLength: v.digestBytes!, key: Data(key)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE2b salt+personalization", arguments: file.saltPersonalization!)
    func saltPersVector(v: SaltPersVector) {
        let input = Array(v.input.utf8)
        let salt = Array(v.salt.utf8)
        let pers = Array(v.personalization.utf8)
        let actual = VectorLoader.toHex(BLAKE2b.hash(Data(input), digestLength: v.digestBytes, salt: Data(salt), personalization: Data(pers)))
        #expect(actual == v.expected)
    }
}

// MARK: - BLAKE2s vector parity

@Suite("Vector Parity — BLAKE2s")
struct BLAKE2sVectorParityTests {
    static let file: BLAKE2File = {
        let decoder = JSONDecoder()
        return try! decoder.decode(BLAKE2File.self, from: VectorLoader.loadData("blake2s.json"))
    }()

    @Test("BLAKE2s hash", arguments: file.hash)
    func hashVector(v: HashVector) {
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2s.hash(Data(input), digestLength: v.digestBytes!))
        #expect(actual == v.expected)
    }

    @Test("BLAKE2s keyed", arguments: file.keyed.vectors)
    func keyedVector(v: HashVector) {
        let key = VectorLoader.hexToBytes(Self.file.keyed.keyHex)
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2s.hash(Data(input), digestLength: v.digestBytes!, key: Data(key)))
        #expect(actual == v.expected)
    }
}

// MARK: - BLAKE2bp vector parity

@Suite("Vector Parity — BLAKE2bp")
struct BLAKE2bpVectorParityTests {
    static let file: BLAKE2ParallelFile = {
        let decoder = JSONDecoder()
        return try! decoder.decode(BLAKE2ParallelFile.self, from: VectorLoader.loadData("blake2bp.json"))
    }()

    @Test("BLAKE2bp hash", arguments: file.hash)
    func hashVector(v: HashVector) {
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2bp.hash(Data(input)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE2bp keyed", arguments: file.keyed.vectors)
    func keyedVector(v: HashVector) {
        let key = VectorLoader.hexToBytes(Self.file.keyed.keyHex)
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2bp.hash(Data(input), key: Data(key)))
        #expect(actual == v.expected)
    }
}

// MARK: - BLAKE2sp vector parity

@Suite("Vector Parity — BLAKE2sp")
struct BLAKE2spVectorParityTests {
    static let file: BLAKE2ParallelFile = {
        let decoder = JSONDecoder()
        return try! decoder.decode(BLAKE2ParallelFile.self, from: VectorLoader.loadData("blake2sp.json"))
    }()

    @Test("BLAKE2sp hash", arguments: file.hash)
    func hashVector(v: HashVector) {
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2sp.hash(Data(input)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE2sp keyed", arguments: file.keyed.vectors)
    func keyedVector(v: HashVector) {
        let key = VectorLoader.hexToBytes(Self.file.keyed.keyHex)
        let input = VectorLoader.resolveInput(v)
        let actual = VectorLoader.toHex(BLAKE2sp.hash(Data(input), key: Data(key)))
        #expect(actual == v.expected)
    }
}

// MARK: - BLAKE3 vector parity

@Suite("Vector Parity — BLAKE3")
struct BLAKE3VectorParityTests {
    static let file: BLAKE3File = {
        let decoder = JSONDecoder()
        return try! decoder.decode(BLAKE3File.self, from: VectorLoader.loadData("blake3.json"))
    }()

    @Test("BLAKE3 hash named", arguments: file.hash.named)
    func hashNamedVector(v: HashVector) {
        let input = Array((v.input ?? "").utf8)
        let actual = VectorLoader.toHex(BLAKE3.hash(Data(input)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE3 hash sequential", arguments: file.hash.sequential)
    func hashSequentialVector(v: HashVector) {
        let input = VectorLoader.blake3Input(v.inputLength!)
        let actual = VectorLoader.toHex(BLAKE3.hash(Data(input)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE3 keyed hash", arguments: file.keyedHash)
    func keyedHashVector(v: HashVector) {
        let key = VectorLoader.hexToBytes(Self.file.keyHex)
        let input = VectorLoader.blake3Input(v.inputLength!)
        let actual = VectorLoader.toHex(BLAKE3.keyedHash(key: Data(key), data: Data(input)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE3 derive key", arguments: file.deriveKey)
    func deriveKeyVector(v: HashVector) {
        let input = VectorLoader.blake3Input(v.inputLength!)
        let actual = VectorLoader.toHex(BLAKE3.deriveKey(context: Self.file.deriveKeyContext, keyMaterial: Data(input)))
        #expect(actual == v.expected)
    }

    @Test("BLAKE3 XOF hash", arguments: file.xof.hash)
    func xofHashVector(v: HashVector) {
        let input = Array((v.input ?? "").utf8)
        var hasher = BLAKE3.Hasher()
        hasher.update(Data(input))
        let out = v.outputBytes == 32 ? hasher.finalize() : hasher.finalizeXof(outputLength: v.outputBytes!)
        #expect(VectorLoader.toHex(out) == v.expected)
    }

    @Test("BLAKE3 XOF keyed", arguments: file.xof.keyed)
    func xofKeyedVector(v: HashVector) {
        let input = Array((v.input ?? "").utf8)
        let key = VectorLoader.hexToBytes(Self.file.keyHex)
        var hasher = BLAKE3.Hasher(key: Data(key))
        hasher.update(Data(input))
        let out = v.outputBytes == 32 ? hasher.finalize() : hasher.finalizeXof(outputLength: v.outputBytes!)
        #expect(VectorLoader.toHex(out) == v.expected)
    }

    @Test("BLAKE3 XOF derive key", arguments: file.xof.deriveKey)
    func xofDeriveKeyVector(v: HashVector) {
        let input = Array((v.input ?? "").utf8)
        var hasher = BLAKE3.Hasher.deriveKey(context: Self.file.deriveKeyContext)
        hasher.update(Data(input))
        let out = v.outputBytes == 32 ? hasher.finalize() : hasher.finalizeXof(outputLength: v.outputBytes!)
        #expect(VectorLoader.toHex(out) == v.expected)
    }
}
