// Internal shared components for the BLAKE2 hash family.
// Optimized with unsafe pointer access for performance-critical paths.
// Specialized compression functions for BLAKE2b (UInt64) and BLAKE2s (UInt32).

// MARK: - Flattened SIGMA Permutation Schedule
// Indexed as blake2SigmaFlat[round * 16 + i] — eliminates nested array indirection.

private let blake2SigmaFlat: [Int] = [
     0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
    14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3,
    11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4,
     7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8,
     9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13,
     2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9,
    12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11,
    13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10,
     6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5,
    10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0,
]

// MARK: - Variant Protocol

internal protocol BLAKE2Variant {
    associatedtype Word: FixedWidthInteger & UnsignedInteger & Sendable
    static var iv: [Word] { get }
    static var blockSize: Int { get }
    static var rounds: Int { get }
    static var maxDigestLength: Int { get }
    static var maxKeyLength: Int { get }
    static var maxSaltLength: Int { get }
    static var maxPersonalizationLength: Int { get }
    static func compress(
        h: inout [Word], block: [UInt8], blockOffset: Int,
        t0: Word, t1: Word, lastBlock: Bool, lastNode: Bool,
        v: inout [Word], m: inout [Word]
    )
}

// MARK: - BLAKE2b Constants

internal enum BLAKE2bVariant: BLAKE2Variant {
    typealias Word = UInt64
    static let iv: [UInt64] = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
        0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f,
        0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ]
    static let blockSize = 128
    static let rounds = 12
    static let maxDigestLength = 64
    static let maxKeyLength = 64
    static let maxSaltLength = 16
    static let maxPersonalizationLength = 16

    @inline(__always)
    static func compress(
        h: inout [UInt64], block: [UInt8], blockOffset: Int,
        t0: UInt64, t1: UInt64, lastBlock: Bool, lastNode: Bool,
        v: inout [UInt64], m: inout [UInt64]
    ) {
        blake2bCompressImpl(h: &h, block: block, blockOffset: blockOffset,
                            t0: t0, t1: t1, lastBlock: lastBlock, lastNode: lastNode,
                            v: &v, m: &m)
    }
}

// MARK: - BLAKE2s Constants

internal enum BLAKE2sVariant: BLAKE2Variant {
    typealias Word = UInt32
    static let iv: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]
    static let blockSize = 64
    static let rounds = 10
    static let maxDigestLength = 32
    static let maxKeyLength = 32
    static let maxSaltLength = 8
    static let maxPersonalizationLength = 8

    @inline(__always)
    static func compress(
        h: inout [UInt32], block: [UInt8], blockOffset: Int,
        t0: UInt32, t1: UInt32, lastBlock: Bool, lastNode: Bool,
        v: inout [UInt32], m: inout [UInt32]
    ) {
        blake2sCompressImpl(h: &h, block: block, blockOffset: blockOffset,
                            t0: t0, t1: t1, lastBlock: lastBlock, lastNode: lastNode,
                            v: &v, m: &m)
    }
}

// MARK: - BLAKE2b Specialized G Function

@inline(__always)
private func blake2bG(
    _ v: UnsafeMutablePointer<UInt64>,
    _ a: Int, _ b: Int, _ c: Int, _ d: Int,
    _ x: UInt64, _ y: UInt64
) {
    v[a] = v[a] &+ v[b] &+ x
    var tmp = v[d] ^ v[a]
    v[d] = (tmp &>> 32) | (tmp &<< 32)
    v[c] = v[c] &+ v[d]
    tmp = v[b] ^ v[c]
    v[b] = (tmp &>> 24) | (tmp &<< 40)
    v[a] = v[a] &+ v[b] &+ y
    tmp = v[d] ^ v[a]
    v[d] = (tmp &>> 16) | (tmp &<< 48)
    v[c] = v[c] &+ v[d]
    tmp = v[b] ^ v[c]
    v[b] = (tmp &>> 63) | (tmp &<< 1)
}

// MARK: - BLAKE2b Specialized Compression

private func blake2bCompressImpl(
    h: inout [UInt64], block: [UInt8], blockOffset: Int,
    t0: UInt64, t1: UInt64, lastBlock: Bool, lastNode: Bool,
    v: inout [UInt64], m: inout [UInt64]
) {
    // Load 16 message words via single unaligned loads
    block.withUnsafeBytes { blockRaw in
        m.withUnsafeMutableBufferPointer { mBuf in
            let mp = mBuf.baseAddress!
            let bp = blockRaw.baseAddress!
            for i in 0..<16 {
                mp[i] = UInt64(littleEndian: bp.loadUnaligned(
                    fromByteOffset: blockOffset + i * 8, as: UInt64.self))
            }
        }
    }

    // Compression rounds using unsafe pointers — no bounds checking
    h.withUnsafeMutableBufferPointer { hBuf in
        v.withUnsafeMutableBufferPointer { vBuf in
            m.withUnsafeBufferPointer { mBuf in
                blake2SigmaFlat.withUnsafeBufferPointer { sigBuf in
                    let hp = hBuf.baseAddress!
                    let vp = vBuf.baseAddress!
                    let mp = mBuf.baseAddress!
                    let sp = sigBuf.baseAddress!

                    for i in 0..<8 { vp[i] = hp[i] }
                    vp[8]  = 0x6a09e667f3bcc908
                    vp[9]  = 0xbb67ae8584caa73b
                    vp[10] = 0x3c6ef372fe94f82b
                    vp[11] = 0xa54ff53a5f1d36f1
                    vp[12] = 0x510e527fade682d1 ^ t0
                    vp[13] = 0x9b05688c2b3e6c1f ^ t1
                    vp[14] = lastBlock ? (0x1f83d9abfb41bd6b ^ ~UInt64(0)) : 0x1f83d9abfb41bd6b
                    vp[15] = lastNode ? (0x5be0cd19137e2179 ^ ~UInt64(0)) : 0x5be0cd19137e2179

                    for round in 0..<12 {
                        let s = sp + (round % 10) * 16
                        blake2bG(vp, 0, 4,  8, 12, mp[s[ 0]], mp[s[ 1]])
                        blake2bG(vp, 1, 5,  9, 13, mp[s[ 2]], mp[s[ 3]])
                        blake2bG(vp, 2, 6, 10, 14, mp[s[ 4]], mp[s[ 5]])
                        blake2bG(vp, 3, 7, 11, 15, mp[s[ 6]], mp[s[ 7]])
                        blake2bG(vp, 0, 5, 10, 15, mp[s[ 8]], mp[s[ 9]])
                        blake2bG(vp, 1, 6, 11, 12, mp[s[10]], mp[s[11]])
                        blake2bG(vp, 2, 7,  8, 13, mp[s[12]], mp[s[13]])
                        blake2bG(vp, 3, 4,  9, 14, mp[s[14]], mp[s[15]])
                    }

                    for i in 0..<8 { hp[i] ^= vp[i] ^ vp[i + 8] }
                }
            }
        }
    }
}

// MARK: - BLAKE2s Specialized G Function

@inline(__always)
private func blake2sG(
    _ v: UnsafeMutablePointer<UInt32>,
    _ a: Int, _ b: Int, _ c: Int, _ d: Int,
    _ x: UInt32, _ y: UInt32
) {
    v[a] = v[a] &+ v[b] &+ x
    var tmp = v[d] ^ v[a]
    v[d] = (tmp &>> 16) | (tmp &<< 16)
    v[c] = v[c] &+ v[d]
    tmp = v[b] ^ v[c]
    v[b] = (tmp &>> 12) | (tmp &<< 20)
    v[a] = v[a] &+ v[b] &+ y
    tmp = v[d] ^ v[a]
    v[d] = (tmp &>> 8) | (tmp &<< 24)
    v[c] = v[c] &+ v[d]
    tmp = v[b] ^ v[c]
    v[b] = (tmp &>> 7) | (tmp &<< 25)
}

// MARK: - BLAKE2s Specialized Compression

private func blake2sCompressImpl(
    h: inout [UInt32], block: [UInt8], blockOffset: Int,
    t0: UInt32, t1: UInt32, lastBlock: Bool, lastNode: Bool,
    v: inout [UInt32], m: inout [UInt32]
) {
    block.withUnsafeBytes { blockRaw in
        m.withUnsafeMutableBufferPointer { mBuf in
            let mp = mBuf.baseAddress!
            let bp = blockRaw.baseAddress!
            for i in 0..<16 {
                mp[i] = UInt32(littleEndian: bp.loadUnaligned(
                    fromByteOffset: blockOffset + i * 4, as: UInt32.self))
            }
        }
    }

    h.withUnsafeMutableBufferPointer { hBuf in
        v.withUnsafeMutableBufferPointer { vBuf in
            m.withUnsafeBufferPointer { mBuf in
                blake2SigmaFlat.withUnsafeBufferPointer { sigBuf in
                    let hp = hBuf.baseAddress!
                    let vp = vBuf.baseAddress!
                    let mp = mBuf.baseAddress!
                    let sp = sigBuf.baseAddress!

                    for i in 0..<8 { vp[i] = hp[i] }
                    vp[8]  = 0x6a09e667
                    vp[9]  = 0xbb67ae85
                    vp[10] = 0x3c6ef372
                    vp[11] = 0xa54ff53a
                    vp[12] = 0x510e527f ^ t0
                    vp[13] = 0x9b05688c ^ t1
                    vp[14] = lastBlock ? (0x1f83d9ab ^ ~UInt32(0)) : 0x1f83d9ab
                    vp[15] = lastNode ? (0x5be0cd19 ^ ~UInt32(0)) : 0x5be0cd19

                    for round in 0..<10 {
                        let s = sp + (round % 10) * 16
                        blake2sG(vp, 0, 4,  8, 12, mp[s[ 0]], mp[s[ 1]])
                        blake2sG(vp, 1, 5,  9, 13, mp[s[ 2]], mp[s[ 3]])
                        blake2sG(vp, 2, 6, 10, 14, mp[s[ 4]], mp[s[ 5]])
                        blake2sG(vp, 3, 7, 11, 15, mp[s[ 6]], mp[s[ 7]])
                        blake2sG(vp, 0, 5, 10, 15, mp[s[ 8]], mp[s[ 9]])
                        blake2sG(vp, 1, 6, 11, 12, mp[s[10]], mp[s[11]])
                        blake2sG(vp, 2, 7,  8, 13, mp[s[12]], mp[s[13]])
                        blake2sG(vp, 3, 4,  9, 14, mp[s[14]], mp[s[15]])
                    }

                    for i in 0..<8 { hp[i] ^= vp[i] ^ vp[i + 8] }
                }
            }
        }
    }
}

// MARK: - Streaming Engine

internal struct BLAKE2Engine<V: BLAKE2Variant>: Sendable {
    private var h: [V.Word]
    private var t0: V.Word
    private var t1: V.Word
    private var buffer: [UInt8]
    private var bufferLength: Int
    internal let digestLength: Int
    internal var isLastNode: Bool
    private var finalized: Bool

    private var v: [V.Word]
    private var m: [V.Word]

    internal init(h: [V.Word], digestLength: Int, key: [UInt8] = []) {
        self.h = h
        self.t0 = 0
        self.t1 = 0
        self.digestLength = digestLength
        self.isLastNode = false
        self.finalized = false
        self.buffer = [UInt8](repeating: 0, count: V.blockSize)
        self.v = [V.Word](repeating: 0, count: 16)
        self.m = [V.Word](repeating: 0, count: 16)

        if !key.isEmpty {
            buffer.withUnsafeMutableBytes { bufRaw in
                key.withUnsafeBytes { keyRaw in
                    bufRaw.baseAddress!.copyMemory(
                        from: keyRaw.baseAddress!, byteCount: key.count)
                }
            }
            self.bufferLength = V.blockSize
        } else {
            self.bufferLength = 0
        }
    }

    internal mutating func update(_ input: [UInt8]) {
        update(input, offset: 0, length: input.count)
    }

    internal mutating func update(_ input: [UInt8], offset: Int, length: Int) {
        precondition(!finalized)
        guard length > 0 else { return }

        var inputOffset = offset
        var remaining = length

        if bufferLength > 0 {
            let toCopy = min(remaining, V.blockSize - bufferLength)
            let bl = bufferLength
            buffer.withUnsafeMutableBytes { bufRaw in
                input.withUnsafeBytes { inputRaw in
                    (bufRaw.baseAddress! + bl).copyMemory(
                        from: inputRaw.baseAddress! + inputOffset, byteCount: toCopy)
                }
            }
            bufferLength += toCopy
            inputOffset += toCopy
            remaining -= toCopy

            if bufferLength == V.blockSize && remaining > 0 {
                incrementCounter(V.blockSize)
                V.compress(h: &h, block: buffer, blockOffset: 0,
                           t0: t0, t1: t1, lastBlock: false, lastNode: false,
                           v: &v, m: &m)
                bufferLength = 0
            }
        }

        while remaining > V.blockSize {
            incrementCounter(V.blockSize)
            V.compress(h: &h, block: input, blockOffset: inputOffset,
                       t0: t0, t1: t1, lastBlock: false, lastNode: false,
                       v: &v, m: &m)
            inputOffset += V.blockSize
            remaining -= V.blockSize
        }

        if remaining > 0 {
            buffer.withUnsafeMutableBytes { bufRaw in
                input.withUnsafeBytes { inputRaw in
                    bufRaw.baseAddress!.copyMemory(
                        from: inputRaw.baseAddress! + inputOffset, byteCount: remaining)
                }
            }
            bufferLength = remaining
        }
    }

    internal mutating func finalize() -> [UInt8] {
        precondition(!finalized)
        finalized = true

        incrementCounter(bufferLength)
        let bl = bufferLength
        buffer.withUnsafeMutableBytes { bufRaw in
            let p = bufRaw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            for i in bl..<V.blockSize { p[i] = 0 }
        }
        V.compress(h: &h, block: buffer, blockOffset: 0,
                   t0: t0, t1: t1, lastBlock: true, lastNode: isLastNode,
                   v: &v, m: &m)

        // Convert hash state to bytes via direct memory copy (little-endian)
        var output = [UInt8](repeating: 0, count: digestLength)
        h.withUnsafeBytes { hRaw in
            output.withUnsafeMutableBytes { outRaw in
                outRaw.baseAddress!.copyMemory(
                    from: hRaw.baseAddress!, byteCount: digestLength)
            }
        }
        return output
    }

    private mutating func incrementCounter(_ n: Int) {
        let nw = V.Word(truncatingIfNeeded: n)
        let old = t0
        t0 = t0 &+ nw
        if t0 < old {
            t1 = t1 &+ 1
        }
    }
}

// MARK: - Parameter Block Builders

internal func blake2bInitializeState(
    digestLength: Int,
    keyLength: Int,
    fanout: Int = 1,
    depth: Int = 1,
    leafLength: UInt32 = 0,
    nodeOffset: UInt64 = 0,
    nodeDepth: Int = 0,
    innerLength: Int = 0,
    salt: [UInt8] = [],
    personalization: [UInt8] = []
) -> [UInt64] {
    var p = [UInt8](repeating: 0, count: 64)

    p[0] = UInt8(digestLength)
    p[1] = UInt8(keyLength)
    p[2] = UInt8(fanout)
    p[3] = UInt8(depth)

    p[4] = UInt8(truncatingIfNeeded: leafLength)
    p[5] = UInt8(truncatingIfNeeded: leafLength >> 8)
    p[6] = UInt8(truncatingIfNeeded: leafLength >> 16)
    p[7] = UInt8(truncatingIfNeeded: leafLength >> 24)

    for i in 0..<8 {
        p[8 + i] = UInt8(truncatingIfNeeded: nodeOffset >> (i * 8))
    }

    p[16] = UInt8(nodeDepth)
    p[17] = UInt8(innerLength)

    for i in 0..<min(salt.count, 16) { p[32 + i] = salt[i] }
    for i in 0..<min(personalization.count, 16) { p[48 + i] = personalization[i] }

    var h = BLAKE2bVariant.iv
    p.withUnsafeBytes { pRaw in
        h.withUnsafeMutableBufferPointer { hBuf in
            let hp = hBuf.baseAddress!
            let pp = pRaw.baseAddress!
            for i in 0..<8 {
                hp[i] ^= UInt64(littleEndian: pp.loadUnaligned(
                    fromByteOffset: i * 8, as: UInt64.self))
            }
        }
    }
    return h
}

internal func blake2sInitializeState(
    digestLength: Int,
    keyLength: Int,
    fanout: Int = 1,
    depth: Int = 1,
    leafLength: UInt32 = 0,
    nodeOffset: UInt64 = 0,
    nodeDepth: Int = 0,
    innerLength: Int = 0,
    salt: [UInt8] = [],
    personalization: [UInt8] = []
) -> [UInt32] {
    var p = [UInt8](repeating: 0, count: 32)

    p[0] = UInt8(digestLength)
    p[1] = UInt8(keyLength)
    p[2] = UInt8(fanout)
    p[3] = UInt8(depth)

    p[4] = UInt8(truncatingIfNeeded: leafLength)
    p[5] = UInt8(truncatingIfNeeded: leafLength >> 8)
    p[6] = UInt8(truncatingIfNeeded: leafLength >> 16)
    p[7] = UInt8(truncatingIfNeeded: leafLength >> 24)

    for i in 0..<6 {
        p[8 + i] = UInt8(truncatingIfNeeded: nodeOffset >> (i * 8))
    }

    p[14] = UInt8(nodeDepth)
    p[15] = UInt8(innerLength)

    for i in 0..<min(salt.count, 8) { p[16 + i] = salt[i] }
    for i in 0..<min(personalization.count, 8) { p[24 + i] = personalization[i] }

    var h = BLAKE2sVariant.iv
    p.withUnsafeBytes { pRaw in
        h.withUnsafeMutableBufferPointer { hBuf in
            let hp = hBuf.baseAddress!
            let pp = pRaw.baseAddress!
            for i in 0..<8 {
                hp[i] ^= UInt32(littleEndian: pp.loadUnaligned(
                    fromByteOffset: i * 4, as: UInt32.self))
            }
        }
    }
    return h
}
