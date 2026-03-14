import Foundation
import Testing
@testable import BlakeHash

@Suite("BLAKE3 Keyed Hash")
struct BLAKE3KeyedTests {

    static let key: [UInt8] = [UInt8](0..<32)

    static let vectors: [(len: Int, hash: String)] = [
        (0, "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f"),
        (1, "d08b45c6b127ee94f3f8527a0b82a5f80be1695a0eaec6022e772c0eb95a7e8b"),
        (64, "cfaf838ff320e0d87301dcba02b1a4bb397d65119f57403df2817a51d4025f9b"),
        (65, "d8a45528bfa93a0d9b7bf4c840b68f64af0b9ad3d0bbd6c1421c2a4cf1cdf3b4"),
        (1024, "f45a9249a627fdf1fcf13c0e6376f6a9a9b2056d6e1b5693a4b119a3453665f9"),
        (1025, "82223147a9b804a0c3f9a921b8d8aee250d1a51bb76be72152e6d5e8f27349b3"),
    ]

    @Test("keyed hash vector", arguments: vectors)
    func keyedHashVector(vector: (len: Int, hash: String)) {
        let input = blake3Input(vector.len)
        let hash = BLAKE3.keyedHash(key: Data(BLAKE3KeyedTests.key), data: input)
        #expect(toHex(hash) == vector.hash, "Failed for input length \(vector.len)")
    }

    @Test("keyed hash streaming matches one-shot")
    func streamingParity() {
        let input = blake3Input(1025)
        let oneShot = BLAKE3.keyedHash(key: Data(BLAKE3KeyedTests.key), data: input)

        var hasher = BLAKE3.Hasher(key: Data(BLAKE3KeyedTests.key))
        for chunk in stride(from: 0, to: input.count, by: 137) {
            let end = min(chunk + 137, input.count)
            hasher.update(input[chunk..<end])
        }
        let streamed = hasher.finalize()

        #expect(oneShot == streamed)
    }
}
