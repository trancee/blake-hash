import Testing
@testable import BlakeHash

private func sequentialBytes(_ n: Int) -> [UInt8] {
    (0..<n).map { UInt8($0 % 256) }
}

// MARK: - BLAKE2b Tests

@Suite("BLAKE2b – Empty Input")
struct Blake2bEmptyTests {
    @Test func blake2b256Empty() {
        let result = Blake2b.hash([], digestLength: 32)
        #expect(toHex(result) == "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8")
    }

    @Test func blake2b384Empty() {
        let result = Blake2b.hash([], digestLength: 48)
        #expect(toHex(result) == "b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100")
    }

    @Test func blake2b512Empty() {
        let result = Blake2b.hash([], digestLength: 64)
        #expect(toHex(result) == "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce")
    }
}

@Suite("BLAKE2b – abc")
struct Blake2bAbcTests {
    let abc: [UInt8] = Array("abc".utf8)

    @Test func blake2b256Abc() {
        let result = Blake2b.hash(abc, digestLength: 32)
        #expect(toHex(result) == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")
    }

    @Test func blake2b384Abc() {
        let result = Blake2b.hash(abc, digestLength: 48)
        #expect(toHex(result) == "6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4")
    }

    @Test func blake2b512Abc() {
        let result = Blake2b.hash(abc, digestLength: 64)
        #expect(toHex(result) == "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
    }
}

@Suite("BLAKE2b – Quick Brown Fox")
struct Blake2bFoxTests {
    let fox: [UInt8] = Array("The quick brown fox jumps over the lazy dog".utf8)

    @Test func blake2b256Fox() {
        let result = Blake2b.hash(fox, digestLength: 32)
        #expect(toHex(result) == "01718cec35cd3d796dd00020e0bfecb473ad23457d063b75eff29c0ffa2e58a9")
    }

    @Test func blake2b512Fox() {
        let result = Blake2b.hash(fox, digestLength: 64)
        #expect(toHex(result) == "a8add4bdddfd93e4877d2746e62817b116364a1fa7bc148d95090bc7333b3673f82401cf7aa2e4cb1ecd90296e3f14cb5413f8ed77be73045b13914cdcd6a918")
    }
}

@Suite("BLAKE2b – Sequential Inputs")
struct Blake2bSequentialTests {
    @Test func sequential64() {
        let result = Blake2b.hash(sequentialBytes(64), digestLength: 64)
        #expect(toHex(result) == "2fc6e69fa26a89a5ed269092cb9b2a449a4409a7a44011eecad13d7c4b0456602d402fa5844f1a7a758136ce3d5d8d0e8b86921ffff4f692dd95bdc8e5ff0052")
    }

    @Test func sequential128() {
        let result = Blake2b.hash(sequentialBytes(128), digestLength: 64)
        #expect(toHex(result) == "2319e3789c47e2daa5fe807f61bec2a1a6537fa03f19ff32e87eecbfd64b7e0e8ccff439ac333b040f19b0c4ddd11a61e24ac1fe0f10a039806c5dcc0da3d115")
    }

    @Test func sequential256() {
        let result = Blake2b.hash(sequentialBytes(256), digestLength: 64)
        #expect(toHex(result) == "1ecc896f34d3f9cac484c73f75f6a5fb58ee6784be41b35f46067b9c65c63a6794d3d744112c653f73dd7deb6666204c5a9bfa5b46081fc10fdbe7884fa5cbf8")
    }
}

@Suite("BLAKE2b – Keyed Hashing")
struct Blake2bKeyedTests {
    let key: [UInt8] = (0..<64).map { UInt8($0) }

    @Test func keyedEmpty() {
        let result = Blake2b.hash([], digestLength: 64, key: key)
        #expect(toHex(result) == "10ebb67700b1868efb4417987acf4690ae9d972fb7a590c2f02871799aaa4786b5e996e8f0f4eb981fc214b005f42d2ff4233499391653df7aefcbc13fc51568")
    }

    @Test func keyedAbc() {
        let result = Blake2b.hash(Array("abc".utf8), digestLength: 64, key: key)
        #expect(toHex(result) == "06bbc3dedf13a31139498655251b7588ccd3bb5aaa071b2d44d8e0a04095579ed590fbfdcf941f4370ce5ce623624e7a76d33e7a8109dcda9b57d72f8f8efa51")
    }
}

@Suite("BLAKE2b – Streaming Consistency")
struct Blake2bStreamingTests {
    @Test func streamingMatchesOneShot() {
        let input: [UInt8] = Array("abc".utf8)
        let oneShot = Blake2b.hash(input, digestLength: 64)

        var hasher = Blake2b.Hasher(digestLength: 64)
        for byte in input {
            hasher.update([byte])
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }

    @Test func streamingLargeChunked() {
        let input = sequentialBytes(256)
        let oneShot = Blake2b.hash(input, digestLength: 64)

        var hasher = Blake2b.Hasher(digestLength: 64)
        var offset = 0
        let chunkSize = 17
        while offset < input.count {
            let end = min(offset + chunkSize, input.count)
            hasher.update(Array(input[offset..<end]))
            offset = end
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }
}
