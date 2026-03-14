import Testing
@testable import BlakeHash

// MARK: - BLAKE2bp Tests

@Suite("BLAKE2bp")
struct Blake2bpTests {
    let abc: [UInt8] = Array("abc".utf8)

    @Test func blake2bpAbc() {
        let result = Blake2bp.hash(abc)
        #expect(toHex(result) == "b91a6b66ae87526c400b0a8b53774dc65284ad8f6575f8148ff93dff943a6ecd8362130f22d6dae633aa0f91df4ac89aaff31d0f1b923c898e82025dedbdad6e")
    }

    @Test func blake2bpKeyedAbc() {
        let key: [UInt8] = (0..<64).map { UInt8($0) }
        let result = Blake2bp.hash(abc, key: key)
        #expect(toHex(result) == "8943f40e65e41fdbbe79b701b26279125bbe120379dd77d74fdb5faf662ed6a3974aa1dce99a3349a492159fa0ded8245a5167c11886170a3af12888448fa8b2")
    }

    @Test func blake2bpDiffersFromBlake2b() {
        let bpResult = Blake2bp.hash(abc)
        let bResult = Blake2b.hash(abc, digestLength: 64)
        #expect(toHex(bpResult) != toHex(bResult))
    }

    @Test func blake2bpStreamingMatchesOneShot() {
        let input: [UInt8] = Array("abc".utf8)
        let oneShot = Blake2bp.hash(input)

        var hasher = Blake2bp.Hasher()
        for byte in input {
            hasher.update([byte])
        }
        let streamed = hasher.finalize()

        #expect(toHex(oneShot) == toHex(streamed))
    }
}
