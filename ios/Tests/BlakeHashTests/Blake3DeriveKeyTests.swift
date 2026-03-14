import Foundation
import Testing
@testable import BlakeHash

@Suite("BLAKE3 Derive Key")
struct BLAKE3DeriveKeyTests {

    static let context = "BLAKE3 2019-12-27 16:29:52 test vectors context"

    static let vectors: [(len: Int, hash: String)] = [
        (0, "2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d"),
        (1, "b3e2e340a117a499c6cf2398a19ee0d29cca2bb7404c73063382693bf66cb06c"),
        (64, "a5c4a7053fa86b64746d4bb688d06ad1f02a18fce9afd3e818fefaa7126bf73e"),
        (65, "51fd05c3c1cfbc8ed67d139ad76f5cf8236cd2acd26627a30c104dfd9d3ff8a8"),
        (1024, "7356cd7720d5b66b6d0697eb3177d9f8d73a4a5c5e968896eb6a689684302706"),
        (1025, "effaa245f065fbf82ac186839a249707c3bddf6d3fdda22d1b95a3c970379bcb"),
    ]

    @Test("derive key vector", arguments: vectors)
    func deriveKeyVector(vector: (len: Int, hash: String)) {
        let input = blake3Input(vector.len)
        let derived = BLAKE3.deriveKey(context: BLAKE3DeriveKeyTests.context, keyMaterial: input)
        #expect(toHex(derived) == vector.hash, "Failed for input length \(vector.len)")
    }

    @Test("derive key streaming matches one-shot")
    func streamingParity() {
        let input = blake3Input(1025)
        let oneShot = BLAKE3.deriveKey(
            context: BLAKE3DeriveKeyTests.context,
            keyMaterial: input
        )

        var hasher = BLAKE3.Hasher.deriveKey(context: BLAKE3DeriveKeyTests.context)
        for chunk in stride(from: 0, to: input.count, by: 200) {
            let end = min(chunk + 200, input.count)
            hasher.update(input[chunk..<end])
        }
        let streamed = hasher.finalize()

        #expect(oneShot == streamed)
    }
}
