// Internal shared components for the BLAKE2 hash family.
// Implements the core compression function, G mixing, and streaming engine
// generically over BLAKE2b (UInt64) and BLAKE2s (UInt32) word sizes.

// MARK: - SIGMA Permutation Schedule

internal let blake2Sigma: [[Int]] = [
    [ 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15],
    [14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3],
    [11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4],
    [ 7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8],
    [ 9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13],
    [ 2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9],
    [12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11],
    [13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10],
    [ 6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5],
    [10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0],
]

// MARK: - Variant Protocol

internal protocol Blake2Variant {
    associatedtype Word: FixedWidthInteger & UnsignedInteger & Sendable
    static var iv: [Word] { get }
    static var blockSize: Int { get }
    static var rounds: Int { get }
    static var r1: Int { get }
    static var r2: Int { get }
    static var r3: Int { get }
    static var r4: Int { get }
    static var maxDigestLength: Int { get }
    static var maxKeyLength: Int { get }
    static var maxSaltLength: Int { get }
    static var maxPersonalizationLength: Int { get }
}

// MARK: - BLAKE2b Constants

internal enum Blake2bVariant: Blake2Variant {
    typealias Word = UInt64
    static let iv: [UInt64] = [
        0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
        0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
        0x510e527fade682d1, 0x9b05688c2b3e6c1f,
        0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
    ]
    static let blockSize = 128
    static let rounds = 12
    static let r1 = 32
    static let r2 = 24
    static let r3 = 16
    static let r4 = 63
    static let maxDigestLength = 64
    static let maxKeyLength = 64
    static let maxSaltLength = 16
    static let maxPersonalizationLength = 16
}

// MARK: - BLAKE2s Constants

internal enum Blake2sVariant: Blake2Variant {
    typealias Word = UInt32
    static let iv: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]
    static let blockSize = 64
    static let rounds = 10
    static let r1 = 16
    static let r2 = 12
    static let r3 = 8
    static let r4 = 7
    static let maxDigestLength = 32
    static let maxKeyLength = 32
    static let maxSaltLength = 8
    static let maxPersonalizationLength = 8
}

// MARK: - Little-Endian Helpers

@inline(__always)
internal func blake2LoadLE<W: FixedWidthInteger>(_ bytes: [UInt8], offset: Int) -> W {
    var value = W.zero
    for i in 0..<(W.bitWidth / 8) {
        value |= W(truncatingIfNeeded: bytes[offset + i]) &<< (i * 8)
    }
    return value
}

@inline(__always)
internal func blake2StoreLE<W: FixedWidthInteger>(_ value: W, to bytes: inout [UInt8], offset: Int) {
    for i in 0..<(W.bitWidth / 8) {
        bytes[offset + i] = UInt8(truncatingIfNeeded: value &>> (i * 8))
    }
}

// MARK: - G Mixing Function

@inline(__always)
internal func blake2G<W: FixedWidthInteger & UnsignedInteger>(
    _ v: inout [W], _ a: Int, _ b: Int, _ c: Int, _ d: Int,
    _ x: W, _ y: W,
    r1: Int, r2: Int, r3: Int, r4: Int
) {
    v[a] = v[a] &+ v[b] &+ x
    var tmp = v[d] ^ v[a]
    v[d] = tmp &>> r1 | tmp &<< (W.bitWidth - r1)
    v[c] = v[c] &+ v[d]
    tmp = v[b] ^ v[c]
    v[b] = tmp &>> r2 | tmp &<< (W.bitWidth - r2)
    v[a] = v[a] &+ v[b] &+ y
    tmp = v[d] ^ v[a]
    v[d] = tmp &>> r3 | tmp &<< (W.bitWidth - r3)
    v[c] = v[c] &+ v[d]
    tmp = v[b] ^ v[c]
    v[b] = tmp &>> r4 | tmp &<< (W.bitWidth - r4)
}

// MARK: - Compression Function

internal func blake2Compress<V: Blake2Variant>(
    _: V.Type,
    h: inout [V.Word],
    block: [UInt8],
    blockOffset: Int,
    t0: V.Word,
    t1: V.Word,
    lastBlock: Bool,
    lastNode: Bool,
    v: inout [V.Word],
    m: inout [V.Word]
) {
    let wordBytes = V.Word.bitWidth / 8

    for i in 0..<16 {
        m[i] = blake2LoadLE(block, offset: blockOffset + i * wordBytes)
    }

    for i in 0..<8 { v[i] = h[i] }
    v[8]  = V.iv[0]
    v[9]  = V.iv[1]
    v[10] = V.iv[2]
    v[11] = V.iv[3]
    v[12] = V.iv[4] ^ t0
    v[13] = V.iv[5] ^ t1
    v[14] = lastBlock ? (V.iv[6] ^ ~V.Word(0)) : V.iv[6]
    v[15] = lastNode ? (V.iv[7] ^ ~V.Word(0)) : V.iv[7]

    for round in 0..<V.rounds {
        let s = blake2Sigma[round % 10]
        // Column step
        blake2G(&v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        blake2G(&v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        blake2G(&v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        blake2G(&v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        // Diagonal step
        blake2G(&v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        blake2G(&v, 1, 6, 11, 12, m[s[10]], m[s[11]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        blake2G(&v, 2, 7,  8, 13, m[s[12]], m[s[13]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
        blake2G(&v, 3, 4,  9, 14, m[s[14]], m[s[15]], r1: V.r1, r2: V.r2, r3: V.r3, r4: V.r4)
    }

    for i in 0..<8 {
        h[i] ^= v[i] ^ v[i + 8]
    }
}

// MARK: - Streaming Engine

internal struct Blake2Engine<V: Blake2Variant>: Sendable {
    private var h: [V.Word]
    private var t0: V.Word
    private var t1: V.Word
    private var buffer: [UInt8]
    private var bufferLength: Int
    internal let digestLength: Int
    internal var isLastNode: Bool
    private var finalized: Bool

    // Pre-allocated working arrays for compress() to avoid per-call allocation
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
            for i in 0..<key.count { self.buffer[i] = key[i] }
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
            buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                                   with: input[inputOffset..<(inputOffset + toCopy)])
            bufferLength += toCopy
            inputOffset += toCopy
            remaining -= toCopy

            if bufferLength == V.blockSize && remaining > 0 {
                incrementCounter(V.blockSize)
                compress(buffer, blockOffset: 0, lastBlock: false, lastNode: false)
                bufferLength = 0
            }
        }

        while remaining > V.blockSize {
            incrementCounter(V.blockSize)
            compress(input, blockOffset: inputOffset, lastBlock: false, lastNode: false)
            inputOffset += V.blockSize
            remaining -= V.blockSize
        }

        if remaining > 0 {
            buffer.replaceSubrange(0..<remaining,
                                   with: input[inputOffset..<(inputOffset + remaining)])
            bufferLength = remaining
        }
    }

    internal mutating func finalize() -> [UInt8] {
        precondition(!finalized)
        finalized = true

        incrementCounter(bufferLength)
        for i in bufferLength..<V.blockSize {
            buffer[i] = 0
        }
        compress(buffer, blockOffset: 0, lastBlock: true, lastNode: isLastNode)

        let wordBytes = V.Word.bitWidth / 8
        var output = [UInt8](repeating: 0, count: 8 * wordBytes)
        for i in 0..<8 {
            blake2StoreLE(h[i], to: &output, offset: i * wordBytes)
        }
        return Array(output.prefix(digestLength))
    }

    private mutating func incrementCounter(_ n: Int) {
        let nw = V.Word(truncatingIfNeeded: n)
        let old = t0
        t0 = t0 &+ nw
        if t0 < old {
            t1 = t1 &+ 1
        }
    }

    private mutating func compress(
        _ block: [UInt8], blockOffset: Int,
        lastBlock: Bool, lastNode: Bool
    ) {
        blake2Compress(
            V.self, h: &h, block: block, blockOffset: blockOffset,
            t0: t0, t1: t1, lastBlock: lastBlock, lastNode: lastNode,
            v: &v, m: &m
        )
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

    // Leaf length (bytes 4-7, little-endian UInt32)
    p[4] = UInt8(truncatingIfNeeded: leafLength)
    p[5] = UInt8(truncatingIfNeeded: leafLength >> 8)
    p[6] = UInt8(truncatingIfNeeded: leafLength >> 16)
    p[7] = UInt8(truncatingIfNeeded: leafLength >> 24)

    // Node offset (bytes 8-15, little-endian UInt64)
    for i in 0..<8 {
        p[8 + i] = UInt8(truncatingIfNeeded: nodeOffset >> (i * 8))
    }

    p[16] = UInt8(nodeDepth)
    p[17] = UInt8(innerLength)
    // bytes 18-31: reserved (already zero)

    // Salt (bytes 32-47)
    for i in 0..<min(salt.count, 16) { p[32 + i] = salt[i] }

    // Personalization (bytes 48-63)
    for i in 0..<min(personalization.count, 16) { p[48 + i] = personalization[i] }

    var h = Blake2bVariant.iv
    for i in 0..<8 {
        let pw: UInt64 = blake2LoadLE(p, offset: i * 8)
        h[i] ^= pw
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

    // Leaf length (bytes 4-7)
    p[4] = UInt8(truncatingIfNeeded: leafLength)
    p[5] = UInt8(truncatingIfNeeded: leafLength >> 8)
    p[6] = UInt8(truncatingIfNeeded: leafLength >> 16)
    p[7] = UInt8(truncatingIfNeeded: leafLength >> 24)

    // Node offset (bytes 8-13, 6 bytes little-endian)
    for i in 0..<6 {
        p[8 + i] = UInt8(truncatingIfNeeded: nodeOffset >> (i * 8))
    }

    p[14] = UInt8(nodeDepth)
    p[15] = UInt8(innerLength)

    // Salt (bytes 16-23)
    for i in 0..<min(salt.count, 8) { p[16 + i] = salt[i] }

    // Personalization (bytes 24-31)
    for i in 0..<min(personalization.count, 8) { p[24 + i] = personalization[i] }

    var h = Blake2sVariant.iv
    for i in 0..<8 {
        let pw: UInt32 = blake2LoadLE(p, offset: i * 4)
        h[i] ^= pw
    }
    return h
}
