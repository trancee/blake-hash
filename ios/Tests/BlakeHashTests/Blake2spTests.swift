import Testing
@testable import BlakeHash

// MARK: - BLAKE2sp Tests

@Suite("BLAKE2sp")
struct Blake2spTests {
    let abc: [UInt8] = Array("abc".utf8)

    @Test func blake2spAbc() {
        let result = Blake2sp.hash(abc)
        #expect(toHex(result) == "70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5")
    }

    @Test func blake2spKeyedAbc() {
        let key: [UInt8] = (0..<32).map { UInt8($0) }
        let result = Blake2sp.hash(abc, key: key)
        #expect(toHex(result) == "b334a26923410dc586088f365ce36a12bedd33e03c0f4a3808a716dca3a721f0")
    }

    @Test func blake2spDiffersFromBlake2s() {
        let spResult = Blake2sp.hash(abc)
        let sResult = Blake2s.hash(abc, digestLength: 32)
        #expect(toHex(spResult) != toHex(sResult))
    }

    @Test func blake2spStreamingMatchesOneShot() {
        let input: [UInt8] = Array("abc".utf8)
        let oneShot = Blake2sp.hash(input)

        var hasher = Blake2sp.Hasher()
        for byte in input {
            hasher.update([byte])
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }
}
