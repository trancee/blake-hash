// BLAKE3 core implementation — compression function, constants, chunk/tree logic.
// Optimized with unsafe pointer access for performance-critical paths.

// MARK: - Constants

internal enum BLAKE3Constants {
    static let BLOCK_LEN = 64
    static let CHUNK_LEN = 1024
    static let KEY_LEN = 32
    static let OUT_LEN = 32

    static let IV: [UInt32] = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
    ]

    // Domain separation flags
    static let CHUNK_START: UInt32 = 1
    static let CHUNK_END: UInt32 = 2
    static let PARENT: UInt32 = 4
    static let ROOT: UInt32 = 8
    static let KEYED_HASH: UInt32 = 16
    static let DERIVE_KEY_CONTEXT: UInt32 = 32
    static let DERIVE_KEY_MATERIAL: UInt32 = 64
}

// Flattened message word permutation — indexed as blake3PermFlat[round * 16 + i]
private let blake3PermFlat: [Int] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8,
    3, 4, 10, 12, 13, 2, 7, 14, 6, 5, 9, 0, 11, 15, 8, 1,
    10, 7, 12, 9, 14, 3, 13, 15, 4, 0, 11, 2, 5, 8, 1, 6,
    12, 13, 9, 11, 15, 10, 14, 8, 7, 2, 5, 3, 0, 1, 6, 4,
    9, 14, 11, 5, 8, 12, 15, 1, 13, 3, 0, 10, 2, 6, 4, 7,
    11, 15, 5, 0, 1, 9, 8, 6, 14, 10, 2, 12, 3, 4, 7, 13,
]

// MARK: - Specialized G Function (UnsafeMutablePointer, hardcoded rotations)

@inline(__always)
private func blake3G(
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

// MARK: - Unsafe Compression Core

@inline(__always)
private func blake3CompressUnsafe(
    cv: UnsafePointer<UInt32>,
    m: UnsafePointer<UInt32>,
    counter: UInt64,
    blockLen: UInt32,
    flags: UInt32,
    out: UnsafeMutablePointer<UInt32>
) {
    out[0] = cv[0]; out[1] = cv[1]; out[2] = cv[2]; out[3] = cv[3]
    out[4] = cv[4]; out[5] = cv[5]; out[6] = cv[6]; out[7] = cv[7]
    out[8]  = 0x6A09E667; out[9]  = 0xBB67AE85
    out[10] = 0x3C6EF372; out[11] = 0xA54FF53A
    out[12] = UInt32(truncatingIfNeeded: counter)
    out[13] = UInt32(truncatingIfNeeded: counter >> 32)
    out[14] = blockLen
    out[15] = flags

    blake3PermFlat.withUnsafeBufferPointer { permBuf in
        let pp = permBuf.baseAddress!
        for round in 0..<7 {
            let p = pp + round * 16
            blake3G(out, 0, 4, 8, 12, m[p[0]], m[p[1]])
            blake3G(out, 1, 5, 9, 13, m[p[2]], m[p[3]])
            blake3G(out, 2, 6, 10, 14, m[p[4]], m[p[5]])
            blake3G(out, 3, 7, 11, 15, m[p[6]], m[p[7]])
            blake3G(out, 0, 5, 10, 15, m[p[8]], m[p[9]])
            blake3G(out, 1, 6, 11, 12, m[p[10]], m[p[11]])
            blake3G(out, 2, 7, 8, 13, m[p[12]], m[p[13]])
            blake3G(out, 3, 4, 9, 14, m[p[14]], m[p[15]])
        }
    }

    let v8 = out[8]; let v9 = out[9]; let v10 = out[10]; let v11 = out[11]
    let v12 = out[12]; let v13 = out[13]; let v14 = out[14]; let v15 = out[15]
    out[0] ^= v8;  out[8]  = v8  ^ cv[0]
    out[1] ^= v9;  out[9]  = v9  ^ cv[1]
    out[2] ^= v10; out[10] = v10 ^ cv[2]
    out[3] ^= v11; out[11] = v11 ^ cv[3]
    out[4] ^= v12; out[12] = v12 ^ cv[4]
    out[5] ^= v13; out[13] = v13 ^ cv[5]
    out[6] ^= v14; out[14] = v14 ^ cv[6]
    out[7] ^= v15; out[15] = v15 ^ cv[7]
}

// MARK: - Public Compression Function

/// Compression function writing into a pre-allocated output array.
internal func blake3CompressInto(
    chainingValue cv: [UInt32],
    blockWords m: [UInt32],
    counter: UInt64,
    blockLen: UInt32,
    flags: UInt32,
    out: inout [UInt32]
) {
    cv.withUnsafeBufferPointer { cvBuf in
        m.withUnsafeBufferPointer { mBuf in
            out.withUnsafeMutableBufferPointer { outBuf in
                blake3CompressUnsafe(
                    cv: cvBuf.baseAddress!,
                    m: mBuf.baseAddress!,
                    counter: counter,
                    blockLen: blockLen,
                    flags: flags,
                    out: outBuf.baseAddress!)
            }
        }
    }
}

/// Returns all 16 output words.
internal func blake3Compress(
    chainingValue cv: [UInt32],
    blockWords m: [UInt32],
    counter: UInt64,
    blockLen: UInt32,
    flags: UInt32
) -> [UInt32] {
    var out = [UInt32](repeating: 0, count: 16)
    blake3CompressInto(chainingValue: cv, blockWords: m, counter: counter,
                       blockLen: blockLen, flags: flags, out: &out)
    return out
}

// MARK: - Helpers

internal func wordsFromBytes(_ bytes: [UInt8]) -> [UInt32] {
    let wordCount = bytes.count / 4
    var words = [UInt32](repeating: 0, count: wordCount)
    bytes.withUnsafeBytes { rawBuf in
        words.withUnsafeMutableBufferPointer { wordsBuf in
            let wp = wordsBuf.baseAddress!
            let bp = rawBuf.baseAddress!
            for i in 0..<wordCount {
                wp[i] = UInt32(littleEndian: bp.loadUnaligned(
                    fromByteOffset: i * 4, as: UInt32.self))
            }
        }
    }
    return words
}

internal func bytesFromWords(_ words: [UInt32]) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: words.count * 4)
    words.withUnsafeBytes { wordsRaw in
        bytes.withUnsafeMutableBytes { bytesRaw in
            bytesRaw.baseAddress!.copyMemory(
                from: wordsRaw.baseAddress!, byteCount: words.count * 4)
        }
    }
    return bytes
}

// MARK: - Output (for root finalization / XOF)

internal struct BLAKE3Output {
    let inputChainingValue: [UInt32]
    let blockWords: [UInt32]
    let counter: UInt64
    let blockLen: UInt32
    let flags: UInt32

    func chainingValue() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: 16)
        blake3CompressInto(
            chainingValue: inputChainingValue,
            blockWords: blockWords,
            counter: counter,
            blockLen: blockLen,
            flags: flags,
            out: &out
        )
        return Array(out[0..<8])
    }

    func rootOutputBytes(outputLength: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: outputLength)
        var outputBlockCounter: UInt64 = 0
        var written = 0
        var compressOut = [UInt32](repeating: 0, count: 16)

        while written < outputLength {
            blake3CompressInto(
                chainingValue: inputChainingValue,
                blockWords: blockWords,
                counter: outputBlockCounter,
                blockLen: blockLen,
                flags: flags | BLAKE3Constants.ROOT,
                out: &compressOut
            )
            let needed = min(64, outputLength - written)
            // Direct memory copy (little-endian) for output bytes
            compressOut.withUnsafeBytes { outRaw in
                result.withUnsafeMutableBytes { resultRaw in
                    (resultRaw.baseAddress! + written).copyMemory(
                        from: outRaw.baseAddress!, byteCount: needed)
                }
            }
            written += needed
            outputBlockCounter += 1
        }
        return result
    }
}

// MARK: - Chunk State

internal struct BLAKE3ChunkState {
    var chainingValue: [UInt32]
    var chunkCounter: UInt64
    var block: [UInt8]
    var blockLen: Int
    var blocksCompressed: Int
    var flags: UInt32

    private var blockWords: [UInt32]
    private var compressOut: [UInt32]

    init(key: [UInt32], chunkCounter: UInt64, flags: UInt32) {
        self.chainingValue = key
        self.chunkCounter = chunkCounter
        self.block = [UInt8](repeating: 0, count: BLAKE3Constants.BLOCK_LEN)
        self.blockLen = 0
        self.blocksCompressed = 0
        self.flags = flags
        self.blockWords = [UInt32](repeating: 0, count: 16)
        self.compressOut = [UInt32](repeating: 0, count: 16)
    }

    var totalLen: Int {
        BLAKE3Constants.BLOCK_LEN * blocksCompressed + blockLen
    }

    private var startFlag: UInt32 {
        blocksCompressed == 0 ? BLAKE3Constants.CHUNK_START : 0
    }

    mutating func update(_ input: [UInt8], offset inputOffset: Int = 0, length inputLength: Int? = nil) {
        let length = inputLength ?? input.count
        var offset = inputOffset
        let end = inputOffset + length
        while offset < end {
            if blockLen == BLAKE3Constants.BLOCK_LEN {
                // Load block words using unaligned loads
                block.withUnsafeBytes { blockRaw in
                    blockWords.withUnsafeMutableBufferPointer { wBuf in
                        let wp = wBuf.baseAddress!
                        let bp = blockRaw.baseAddress!
                        for i in 0..<16 {
                            wp[i] = UInt32(littleEndian: bp.loadUnaligned(
                                fromByteOffset: i * 4, as: UInt32.self))
                        }
                    }
                }
                // Capture values needed inside the closure to avoid exclusivity conflicts
                let compressFlags = flags | startFlag
                let counter = chunkCounter
                blake3CompressInto(
                    chainingValue: chainingValue,
                    blockWords: blockWords,
                    counter: counter,
                    blockLen: UInt32(BLAKE3Constants.BLOCK_LEN),
                    flags: compressFlags,
                    out: &compressOut
                )
                for i in 0..<8 { chainingValue[i] = compressOut[i] }
                blocksCompressed += 1
                for i in 0..<BLAKE3Constants.BLOCK_LEN { block[i] = 0 }
                blockLen = 0
            }

            let want = BLAKE3Constants.BLOCK_LEN - blockLen
            let take = min(want, end - offset)
            let bl = blockLen
            block.withUnsafeMutableBytes { bufRaw in
                input.withUnsafeBytes { inputRaw in
                    (bufRaw.baseAddress! + bl).copyMemory(
                        from: inputRaw.baseAddress! + offset, byteCount: take)
                }
            }
            blockLen += take
            offset += take
        }
    }

    func output() -> BLAKE3Output {
        var words = [UInt32](repeating: 0, count: 16)
        block.withUnsafeBytes { blockRaw in
            words.withUnsafeMutableBufferPointer { wBuf in
                let wp = wBuf.baseAddress!
                let bp = blockRaw.baseAddress!
                let fullWords = blockLen / 4
                for i in 0..<fullWords {
                    wp[i] = UInt32(littleEndian: bp.loadUnaligned(
                        fromByteOffset: i * 4, as: UInt32.self))
                }
                let remainder = blockLen % 4
                if remainder > 0 {
                    var w: UInt32 = 0
                    let base = fullWords * 4
                    for i in 0..<remainder {
                        w |= UInt32(bp.load(fromByteOffset: base + i, as: UInt8.self)) << (i * 8)
                    }
                    wp[fullWords] = w
                }
            }
        }
        var blockFlags = flags | startFlag
        blockFlags |= BLAKE3Constants.CHUNK_END
        return BLAKE3Output(
            inputChainingValue: chainingValue,
            blockWords: words,
            counter: chunkCounter,
            blockLen: UInt32(blockLen),
            flags: blockFlags
        )
    }
}

// MARK: - Parent Node

internal func blake3ParentOutput(
    leftChildCV: [UInt32],
    rightChildCV: [UInt32],
    key: [UInt32],
    flags: UInt32
) -> BLAKE3Output {
    var blockWords = [UInt32](repeating: 0, count: 16)
    for i in 0..<8 {
        blockWords[i] = leftChildCV[i]
        blockWords[i + 8] = rightChildCV[i]
    }
    return BLAKE3Output(
        inputChainingValue: key,
        blockWords: blockWords,
        counter: 0,
        blockLen: UInt32(BLAKE3Constants.BLOCK_LEN),
        flags: flags | BLAKE3Constants.PARENT
    )
}

internal func blake3ParentCV(
    leftChildCV: [UInt32],
    rightChildCV: [UInt32],
    key: [UInt32],
    flags: UInt32
) -> [UInt32] {
    blake3ParentOutput(
        leftChildCV: leftChildCV,
        rightChildCV: rightChildCV,
        key: key,
        flags: flags
    ).chainingValue()
}

// MARK: - Hasher (internal engine)

internal struct BLAKE3Engine {
    var chunkState: BLAKE3ChunkState
    var key: [UInt32]
    var cvStack: [[UInt32]]
    var cvStackLen: Int
    var flags: UInt32

    init(key: [UInt32], flags: UInt32) {
        self.key = key
        self.flags = flags
        self.chunkState = BLAKE3ChunkState(key: key, chunkCounter: 0, flags: flags)
        self.cvStack = []
        self.cvStackLen = 0
    }

    private mutating func pushCV(_ cv: [UInt32]) {
        if cvStackLen < cvStack.count {
            cvStack[cvStackLen] = cv
        } else {
            cvStack.append(cv)
        }
        cvStackLen += 1
    }

    private mutating func popCV() -> [UInt32] {
        cvStackLen -= 1
        return cvStack[cvStackLen]
    }

    private mutating func addChunkChainingValue(_ newCV: [UInt32], totalChunks: UInt64) {
        var cv = newCV
        var count = totalChunks
        while count & 1 != 0 {
            let leftCV = popCV()
            cv = blake3ParentCV(
                leftChildCV: leftCV,
                rightChildCV: cv,
                key: key,
                flags: flags
            )
            count >>= 1
        }
        pushCV(cv)
    }

    mutating func update(_ input: [UInt8]) {
        var offset = 0
        while offset < input.count {
            if chunkState.totalLen == BLAKE3Constants.CHUNK_LEN {
                let chunkCV = chunkState.output().chainingValue()
                let completedChunkIndex = chunkState.chunkCounter
                addChunkChainingValue(chunkCV, totalChunks: completedChunkIndex)
                chunkState = BLAKE3ChunkState(key: key, chunkCounter: completedChunkIndex + 1, flags: flags)
            }

            let want = BLAKE3Constants.CHUNK_LEN - chunkState.totalLen
            let take = min(want, input.count - offset)
            chunkState.update(input, offset: offset, length: take)
            offset += take
        }
    }

    func finalOutput() -> BLAKE3Output {
        var output = chunkState.output()

        var parentNodesRemaining = cvStackLen
        while parentNodesRemaining > 0 {
            parentNodesRemaining -= 1
            output = blake3ParentOutput(
                leftChildCV: cvStack[parentNodesRemaining],
                rightChildCV: output.chainingValue(),
                key: key,
                flags: flags
            )
        }
        return output
    }
}
