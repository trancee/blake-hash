import Foundation
import Testing
@testable import BlakeHash

@Suite("BLAKE3 XOF")
struct BLAKE3XofTests {

    // MARK: - Hash XOF (empty input)

    @Test("hash XOF empty — 32 bytes")
    func hashXofEmpty32() {
        var hasher = BLAKE3.Hasher()
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 32)
        #expect(toHex(out) == "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262")
    }

    @Test("hash XOF empty — 64 bytes")
    func hashXofEmpty64() {
        var hasher = BLAKE3.Hasher()
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 64)
        #expect(toHex(out) == "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
            + "e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a")
    }

    @Test("hash XOF empty — 128 bytes")
    func hashXofEmpty128() {
        var hasher = BLAKE3.Hasher()
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 128)
        let expected =
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
            + "e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a"
            + "26f5487789e8f660afe6c99ef9e0c52b92e7393024a80459cf91f476f9ffdbda"
            + "7001c22e159b402631f277ca96f2defdf1078282314e763699a31c5363165421"
        #expect(toHex(out) == expected)
    }

    // MARK: - Prefix property

    @Test("XOF output is prefix-consistent")
    func prefixProperty() {
        var hasher = BLAKE3.Hasher()
        hasher.update(Data("abc".utf8))

        let out128 = hasher.finalizeXof(outputLength: 128)
        let out64 = hasher.finalizeXof(outputLength: 64)
        let out32 = hasher.finalizeXof(outputLength: 32)

        #expect(out128.prefix(64) == out64)
        #expect(out128.prefix(32) == out32)
        #expect(out64.prefix(32) == out32)
    }

    // MARK: - Keyed XOF (empty input, key=0x00..0x1f)

    static let key: [UInt8] = [UInt8](0..<32)

    @Test("keyed XOF empty — 32 bytes")
    func keyedXofEmpty32() {
        var hasher = BLAKE3.Hasher(key: Data(BLAKE3XofTests.key))
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 32)
        #expect(toHex(out) == "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f")
    }

    @Test("keyed XOF empty — 64 bytes")
    func keyedXofEmpty64() {
        var hasher = BLAKE3.Hasher(key: Data(BLAKE3XofTests.key))
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 64)
        #expect(toHex(out) == "73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f"
            + "097a9b78582396441e22930e5c7c98fd07f896796c81420f14eb9812f0482857")
    }

    // MARK: - Edge cases

    @Test("XOF with 1 byte output")
    func xofOneByte() {
        var hasher = BLAKE3.Hasher()
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 1)
        #expect(out.count == 1)
        #expect(out[out.startIndex] == 0xaf)
    }

    @Test("XOF with 0 byte output")
    func xofZeroBytes() {
        var hasher = BLAKE3.Hasher()
        hasher.update(Data())
        let out = hasher.finalizeXof(outputLength: 0)
        #expect(out.isEmpty)
    }
}
