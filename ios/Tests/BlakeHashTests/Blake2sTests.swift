import Testing
@testable import BlakeHash

private func sequentialBytes(_ n: Int) -> [UInt8] {
    (0..<n).map { UInt8($0 % 256) }
}

// MARK: - BLAKE2s Tests

@Suite("BLAKE2s – Empty Input")
struct Blake2sEmptyTests {
    @Test func blake2s128Empty() {
        let result = Blake2s.hash([], digestLength: 16)
        #expect(toHex(result) == "64550d6ffe2c0a01a14aba1eade0200c")
    }

    @Test func blake2s256Empty() {
        let result = Blake2s.hash([], digestLength: 32)
        #expect(toHex(result) == "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9")
    }
}

@Suite("BLAKE2s – abc")
struct Blake2sAbcTests {
    let abc: [UInt8] = Array("abc".utf8)

    @Test func blake2s128Abc() {
        let result = Blake2s.hash(abc, digestLength: 16)
        #expect(toHex(result) == "aa4938119b1dc7b87cbad0ffd200d0ae")
    }

    @Test func blake2s256Abc() {
        let result = Blake2s.hash(abc, digestLength: 32)
        #expect(toHex(result) == "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982")
    }
}

@Suite("BLAKE2s – Sequential Inputs")
struct Blake2sSequentialTests {
    @Test func sequential1() {
        let result = Blake2s.hash(sequentialBytes(1), digestLength: 32)
        #expect(toHex(result) == "e34d74dbaf4ff4c6abd871cc220451d2ea2648846c7757fbaac82fe51ad64bea")
    }

    @Test func sequential64() {
        let result = Blake2s.hash(sequentialBytes(64), digestLength: 32)
        #expect(toHex(result) == "56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e")
    }

    @Test func sequential128() {
        let result = Blake2s.hash(sequentialBytes(128), digestLength: 32)
        #expect(toHex(result) == "1fa877de67259d19863a2a34bcc6962a2b25fcbf5cbecd7ede8f1fa36688a796")
    }

    @Test func sequential256() {
        let result = Blake2s.hash(sequentialBytes(256), digestLength: 32)
        #expect(toHex(result) == "5fdeb59f681d975f52c8e69c5502e02a12a3afcc5836ba58f42784c439228781")
    }
}

@Suite("BLAKE2s – Keyed Hashing")
struct Blake2sKeyedTests {
    let key: [UInt8] = (0..<32).map { UInt8($0) }

    @Test func keyedEmpty() {
        let result = Blake2s.hash([], digestLength: 32, key: key)
        #expect(toHex(result) == "48a8997da407876b3d79c0d92325ad3b89cbb754d86ab71aee047ad345fd2c49")
    }

    @Test func keyedAbc() {
        let result = Blake2s.hash(Array("abc".utf8), digestLength: 32, key: key)
        #expect(toHex(result) == "a281f725754969a702f6fe36fc591b7def866e4b70173ece402fc01c064d6b65")
    }
}

@Suite("BLAKE2s – Streaming Consistency")
struct Blake2sStreamingTests {
    @Test func streamingMatchesOneShot() {
        let input: [UInt8] = Array("abc".utf8)
        let oneShot = Blake2s.hash(input, digestLength: 32)

        var hasher = Blake2s.Hasher(digestLength: 32)
        for byte in input {
            hasher.update([byte])
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }

    @Test func streamingLargeChunked() {
        let input = sequentialBytes(256)
        let oneShot = Blake2s.hash(input, digestLength: 32)

        var hasher = Blake2s.Hasher(digestLength: 32)
        var offset = 0
        let chunkSize = 13
        while offset < input.count {
            let end = min(offset + chunkSize, input.count)
            hasher.update(Array(input[offset..<end]))
            offset = end
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }
}
