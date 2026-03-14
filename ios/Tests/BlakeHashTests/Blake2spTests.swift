import Foundation
import Testing
@testable import BlakeHash

// MARK: - BLAKE2sp Tests

@Suite("BLAKE2sp")
struct BLAKE2spTests {
    let abc: [UInt8] = Array("abc".utf8)

    @Test func blake2spAbc() {
        let result = BLAKE2sp.hash(Data(abc))
        #expect(toHex(result) == "70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5")
    }

    @Test func blake2spKeyedAbc() {
        let key: [UInt8] = (0..<32).map { UInt8($0) }
        let result = BLAKE2sp.hash(Data(abc), key: Data(key))
        #expect(toHex(result) == "b334a26923410dc586088f365ce36a12bedd33e03c0f4a3808a716dca3a721f0")
    }

    @Test func blake2spDiffersFromBLAKE2s() {
        let spResult = BLAKE2sp.hash(Data(abc))
        let sResult = BLAKE2s.hash(Data(abc), digestLength: 32)
        #expect(toHex(spResult) != toHex(sResult))
    }

    @Test func blake2spStreamingMatchesOneShot() {
        let input: [UInt8] = Array("abc".utf8)
        let oneShot = BLAKE2sp.hash(Data(input))

        var hasher = BLAKE2sp.Hasher()
        for byte in input {
            hasher.update(Data([byte]))
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }
}
