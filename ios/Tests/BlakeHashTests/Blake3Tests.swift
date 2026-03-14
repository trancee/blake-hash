import Foundation
import Testing
@testable import BlakeHash

// MARK: - Named input tests

@Suite("BLAKE3 Hash — Named Inputs")
struct BLAKE3NamedTests {

    @Test("empty input")
    func empty() {
        let hash = BLAKE3.hash(Data())
        #expect(toHex(hash) == "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262")
    }

    @Test("\"abc\"")
    func abc() {
        let hash = BLAKE3.hash(Data("abc".utf8))
        #expect(toHex(hash) == "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85")
    }

    @Test("\"IETF\"")
    func ietf() {
        let hash = BLAKE3.hash(Data("IETF".utf8))
        #expect(toHex(hash) == "83a2de1ee6f4e6ab686889248f4ec0cf4cc5709446a682ffd1cbb4d6165181e2")
    }

    @Test("\"The quick brown fox jumps over the lazy dog\"")
    func quickBrownFox() {
        let hash = BLAKE3.hash(Data("The quick brown fox jumps over the lazy dog".utf8))
        #expect(toHex(hash) == "2f1514181aadccd913abd94cfa592701a5686ab23f8df1dff1b74710febc6d4a")
    }
}

// MARK: - Sequential (i%251) test vectors

@Suite("BLAKE3 Hash — Sequential Vectors")
struct BLAKE3SequentialTests {

    static let vectors: [(len: Int, hash: String)] = [
        (0, "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"),
        (1, "2d3adedff11b61f14c886e35afa036736dcd87a74d27b5c1510225d0f592e213"),
        (2, "7b7015bb92cf0b318037702a6cdd81dee41224f734684c2c122cd6359cb1ee63"),
        (3, "e1be4d7a8ab5560aa4199eea339849ba8e293d55ca0a81006726d184519e647f"),
        (4, "f30f5ab28fe047904037f77b6da4fea1e27241c5d132638d8bedce9d40494f32"),
        (8, "2351207d04fc16ade43ccab08600939c7c1fa70a5c0aaca76063d04c3228eaeb"),
        (63, "e9bc37a594daad83be9470df7f7b3798297c3d834ce80ba85d6e207627b7db7b"),
        (64, "4eed7141ea4a5cd4b788606bd23f46e212af9cacebacdc7d1f4c6dc7f2511b98"),
        (65, "de1e5fa0be70df6d2be8fffd0e99ceaa8eb6e8c93a63f2d8d1c30ecb6b263dee"),
        (128, "f17e570564b26578c33bb7f44643f539624b05df1a76c81f30acd548c44b45ef"),
        (1023, "10108970eeda3eb932baac1428c7a2163b0e924c9a9e25b35bba72b28f70bd11"),
        (1024, "42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7"),
        (1025, "d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444"),
        (2048, "e776b6028c7cd22a4d0ba182a8bf62205d2ef576467e838ed6f2529b85fba24a"),
        (4096, "015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969"),
        (8192, "aae792484c8efe4f19e2ca7d371d8c467ffb10748d8a5a1ae579948f718a2a63"),
        (16384, "f875d6646de28985646f34ee13be9a576fd515f76b5b0a26bb324735041ddde4"),
        (65536, "68d647e619a930e7b1082f74f334b0c65a315725569bdc123f0ee11881717bfe"),
        (131072, "306baba93b1a393cbd35172837c98b0f59a41f64e1b2682ae102d8b2534b9e1c"),
    ]

    @Test("sequential vector", arguments: vectors)
    func sequentialVector(vector: (len: Int, hash: String)) {
        let input = blake3Input(vector.len)
        let hash = BLAKE3.hash(input)
        #expect(toHex(hash) == vector.hash, "Failed for input length \(vector.len)")
    }
}

// MARK: - Streaming parity

@Suite("BLAKE3 Hash — Streaming")
struct BLAKE3StreamingTests {

    @Test("one-shot equals incremental for \"abc\"")
    func oneShotEqualsIncremental() {
        let input = Array("abc".utf8)
        let oneShot = BLAKE3.hash(Data(input))

        var hasher = BLAKE3.Hasher()
        hasher.update(Data(input))
        let incremental = hasher.finalize()

        #expect(oneShot == incremental)
    }

    @Test("byte-by-byte streaming matches one-shot")
    func byteByByte() {
        let input = blake3Input(1025)
        let oneShot = BLAKE3.hash(input)

        var hasher = BLAKE3.Hasher()
        for byte in input {
            hasher.update(Data([byte]))
        }
        let streamed = hasher.finalize()

        #expect(oneShot == streamed)
    }

    @Test("multi-chunk streaming matches one-shot")
    func multiChunk() {
        let input = blake3Input(4096)
        let oneShot = BLAKE3.hash(input)

        var hasher = BLAKE3.Hasher()
        let chunkSize = 100
        var offset = 0
        while offset < input.count {
            let end = min(offset + chunkSize, input.count)
            hasher.update(input[offset..<end])
            offset = end
        }
        let streamed = hasher.finalize()

        #expect(oneShot == streamed)
    }
}
