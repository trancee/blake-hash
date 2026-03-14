import Foundation
import Testing
@testable import BlakeHash

@Suite("Cross-Algorithm — hash \"abc\"")
struct CrossAlgorithmTests {

    static let abc: [UInt8] = Array("abc".utf8)

    @Test("BLAKE2b-512")
    func blake2b512() {
        let hash = BLAKE2b.hash(Data(Self.abc))
        #expect(toHex(hash) == "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1"
            + "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
    }

    @Test("BLAKE2s-256")
    func blake2s256() {
        let hash = BLAKE2s.hash(Data(Self.abc))
        #expect(toHex(hash) == "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982")
    }

    @Test("BLAKE3-256")
    func blake3_256() {
        let hash = BLAKE3.hash(Data(Self.abc))
        #expect(toHex(hash) == "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85")
    }

    @Test("BLAKE2bp-512")
    func blake2bp512() {
        let hash = BLAKE2bp.hash(Data(Self.abc))
        #expect(toHex(hash) == "b91a6b66ae87526c400b0a8b53774dc65284ad8f6575f8148ff93dff943a6ecd"
            + "8362130f22d6dae633aa0f91df4ac89aaff31d0f1b923c898e82025dedbdad6e")
    }

    @Test("BLAKE2sp-256")
    func blake2sp256() {
        let hash = BLAKE2sp.hash(Data(Self.abc))
        #expect(toHex(hash) == "70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5")
    }

    @Test("all algorithms produce distinct outputs")
    func allDistinct() {
        let hashes = [
            toHex(BLAKE2b.hash(Data(Self.abc))),
            toHex(BLAKE2s.hash(Data(Self.abc))),
            toHex(BLAKE3.hash(Data(Self.abc))),
            toHex(BLAKE2bp.hash(Data(Self.abc))),
            toHex(BLAKE2sp.hash(Data(Self.abc))),
        ]
        let unique = Set(hashes)
        #expect(unique.count == hashes.count, "Expected all 5 algorithm outputs to be distinct")
    }
}
