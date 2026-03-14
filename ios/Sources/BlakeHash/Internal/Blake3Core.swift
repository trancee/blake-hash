// BLAKE3 core implementation — compression function, constants, chunk/tree logic.
// Pure Swift, zero external dependencies.

// MARK: - Constants

internal enum Blake3Constants {
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

    // Pre-computed message word permutations for all 7 rounds
    static let MSG_PERMUTATION: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8],
        [3, 4, 10, 12, 13, 2, 7, 14, 6, 5, 9, 0, 11, 15, 8, 1],
        [10, 7, 12, 9, 14, 3, 13, 15, 4, 0, 11, 2, 5, 8, 1, 6],
        [12, 13, 9, 11, 15, 10, 14, 8, 7, 2, 5, 3, 0, 1, 6, 4],
        [9, 14, 11, 5, 8, 12, 15, 1, 13, 3, 0, 10, 2, 6, 4, 7],
        [11, 15, 5, 0, 1, 9, 8, 6, 14, 10, 2, 12, 3, 4, 7, 13],
    ]
}

// MARK: - Helpers

extension UInt32 {
    @inline(__always)
    internal func rotatedRight(by n: Int) -> UInt32 {
        (self >> n) | (self << (32 - n))
    }
}

@inline(__always)
internal func loadLE32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
}

@inline(__always)
internal func storeLE32(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
    bytes[offset] = UInt8(truncatingIfNeeded: value)
    bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    bytes[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}

internal func wordsFromBytes(_ bytes: [UInt8]) -> [UInt32] {
    var words = [UInt32](repeating: 0, count: bytes.count / 4)
    for i in 0..<words.count {
        words[i] = loadLE32(bytes, at: i * 4)
    }
    return words
}

internal func bytesFromWords(_ words: [UInt32]) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: words.count * 4)
    for i in 0..<words.count {
        storeLE32(words[i], into: &bytes, at: i * 4)
    }
    return bytes
}

// MARK: - G Function

@inline(__always)
internal func g(_ v: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int, _ x: UInt32, _ y: UInt32) {
    v[a] = v[a] &+ v[b] &+ x
    v[d] = (v[d] ^ v[a]).rotatedRight(by: 16)
    v[c] = v[c] &+ v[d]
    v[b] = (v[b] ^ v[c]).rotatedRight(by: 12)
    v[a] = v[a] &+ v[b] &+ y
    v[d] = (v[d] ^ v[a]).rotatedRight(by: 8)
    v[c] = v[c] &+ v[d]
    v[b] = (v[b] ^ v[c]).rotatedRight(by: 7)
}

// MARK: - Compression Function

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

/// Compression function writing into a pre-allocated output array.
@inline(__always)
internal func blake3CompressInto(
    chainingValue cv: [UInt32],
    blockWords m: [UInt32],
    counter: UInt64,
    blockLen: UInt32,
    flags: UInt32,
    out: inout [UInt32]
) {
    let iv = Blake3Constants.IV
    // Reuse the output array as working vector
    out[0] = cv[0]; out[1] = cv[1]; out[2] = cv[2]; out[3] = cv[3]
    out[4] = cv[4]; out[5] = cv[5]; out[6] = cv[6]; out[7] = cv[7]
    out[8] = iv[0]; out[9] = iv[1]; out[10] = iv[2]; out[11] = iv[3]
    out[12] = UInt32(truncatingIfNeeded: counter)
    out[13] = UInt32(truncatingIfNeeded: counter >> 32)
    out[14] = blockLen
    out[15] = flags

    for round in 0..<7 {
        let perm = Blake3Constants.MSG_PERMUTATION[round]
        g(&out, 0, 4, 8, 12, m[perm[0]], m[perm[1]])
        g(&out, 1, 5, 9, 13, m[perm[2]], m[perm[3]])
        g(&out, 2, 6, 10, 14, m[perm[4]], m[perm[5]])
        g(&out, 3, 7, 11, 15, m[perm[6]], m[perm[7]])
        g(&out, 0, 5, 10, 15, m[perm[8]], m[perm[9]])
        g(&out, 1, 6, 11, 12, m[perm[10]], m[perm[11]])
        g(&out, 2, 7, 8, 13, m[perm[12]], m[perm[13]])
        g(&out, 3, 4, 9, 14, m[perm[14]], m[perm[15]])
    }

    // Save v[8..15] before overwriting
    let v8 = out[8]; let v9 = out[9]; let v10 = out[10]; let v11 = out[11]
    let v12 = out[12]; let v13 = out[13]; let v14 = out[14]; let v15 = out[15]
    out[0] = out[0] ^ v8;  out[8]  = v8  ^ cv[0]
    out[1] = out[1] ^ v9;  out[9]  = v9  ^ cv[1]
    out[2] = out[2] ^ v10; out[10] = v10 ^ cv[2]
    out[3] = out[3] ^ v11; out[11] = v11 ^ cv[3]
    out[4] = out[4] ^ v12; out[12] = v12 ^ cv[4]
    out[5] = out[5] ^ v13; out[13] = v13 ^ cv[5]
    out[6] = out[6] ^ v14; out[14] = v14 ^ cv[6]
    out[7] = out[7] ^ v15; out[15] = v15 ^ cv[7]
}

// MARK: - Output (for root finalization / XOF)

internal struct Blake3Output {
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
                flags: flags | Blake3Constants.ROOT,
                out: &compressOut
            )
            let needed = min(64, outputLength - written)
            let fullWords = needed / 4
            let remainder = needed % 4
            for i in 0..<fullWords {
                storeLE32(compressOut[i], into: &result, at: written + i * 4)
            }
            if remainder > 0 {
                let w = compressOut[fullWords]
                for j in 0..<remainder {
                    result[written + fullWords * 4 + j] = UInt8(truncatingIfNeeded: w >> (j * 8))
                }
            }
            written += needed
            outputBlockCounter += 1
        }
        return result
    }
}

// MARK: - Chunk State

internal struct Blake3ChunkState {
    var chainingValue: [UInt32]
    var chunkCounter: UInt64
    var block: [UInt8]
    var blockLen: Int
    var blocksCompressed: Int
    var flags: UInt32

    // Pre-allocated working arrays
    private var blockWords: [UInt32]
    private var compressOut: [UInt32]

    init(key: [UInt32], chunkCounter: UInt64, flags: UInt32) {
        self.chainingValue = key
        self.chunkCounter = chunkCounter
        self.block = [UInt8](repeating: 0, count: Blake3Constants.BLOCK_LEN)
        self.blockLen = 0
        self.blocksCompressed = 0
        self.flags = flags
        self.blockWords = [UInt32](repeating: 0, count: 16)
        self.compressOut = [UInt32](repeating: 0, count: 16)
    }

    var totalLen: Int {
        Blake3Constants.BLOCK_LEN * blocksCompressed + blockLen
    }

    private var startFlag: UInt32 {
        blocksCompressed == 0 ? Blake3Constants.CHUNK_START : 0
    }

    mutating func update(_ input: [UInt8], offset inputOffset: Int = 0, length inputLength: Int? = nil) {
        let length = inputLength ?? input.count
        var offset = inputOffset
        let end = inputOffset + length
        while offset < end {
            if blockLen == Blake3Constants.BLOCK_LEN {
                for i in 0..<16 {
                    blockWords[i] = loadLE32(block, at: i * 4)
                }
                blake3CompressInto(
                    chainingValue: chainingValue,
                    blockWords: blockWords,
                    counter: chunkCounter,
                    blockLen: UInt32(Blake3Constants.BLOCK_LEN),
                    flags: flags | startFlag,
                    out: &compressOut
                )
                for i in 0..<8 { chainingValue[i] = compressOut[i] }
                blocksCompressed += 1
                for i in 0..<Blake3Constants.BLOCK_LEN { block[i] = 0 }
                blockLen = 0
            }

            let want = Blake3Constants.BLOCK_LEN - blockLen
            let take = min(want, end - offset)
            block.replaceSubrange(blockLen..<(blockLen + take),
                                  with: input[offset..<(offset + take)])
            blockLen += take
            offset += take
        }
    }

    func output() -> Blake3Output {
        var words = [UInt32](repeating: 0, count: 16)
        let fullWords = blockLen / 4
        for i in 0..<fullWords {
            words[i] = loadLE32(block, at: i * 4)
        }
        let remainder = blockLen % 4
        if remainder > 0 {
            var w: UInt32 = 0
            let base = fullWords * 4
            for i in 0..<remainder {
                w |= UInt32(block[base + i]) << (i * 8)
            }
            words[fullWords] = w
        }
        var blockFlags = flags | startFlag
        blockFlags |= Blake3Constants.CHUNK_END
        return Blake3Output(
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
) -> Blake3Output {
    var blockWords = [UInt32](repeating: 0, count: 16)
    for i in 0..<8 {
        blockWords[i] = leftChildCV[i]
        blockWords[i + 8] = rightChildCV[i]
    }
    return Blake3Output(
        inputChainingValue: key,
        blockWords: blockWords,
        counter: 0,
        blockLen: UInt32(Blake3Constants.BLOCK_LEN),
        flags: flags | Blake3Constants.PARENT
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

internal struct Blake3Engine {
    var chunkState: Blake3ChunkState
    var key: [UInt32]
    var cvStack: [[UInt32]]
    var cvStackLen: Int
    var flags: UInt32

    init(key: [UInt32], flags: UInt32) {
        self.key = key
        self.flags = flags
        self.chunkState = Blake3ChunkState(key: key, chunkCounter: 0, flags: flags)
        self.cvStack = []
        self.cvStackLen = 0
    }

    /// Count of complete chunks so far.
    private var totalChunks: UInt64 {
        chunkState.chunkCounter
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

    /// After completing a chunk, merge as many parent nodes as dictated by the chunk count.
    private mutating func addChunkChainingValue(_ newCV: [UInt32], totalChunks: UInt64) {
        var cv = newCV
        // The number of trailing 1-bits in totalChunks tells us how many merges to do
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
            // If the current chunk is complete, finalize it
            if chunkState.totalLen == Blake3Constants.CHUNK_LEN {
                let chunkCV = chunkState.output().chainingValue()
                let completedChunkIndex = chunkState.chunkCounter
                let nextChunkCounter = completedChunkIndex + 1
                addChunkChainingValue(chunkCV, totalChunks: completedChunkIndex)
                chunkState = Blake3ChunkState(key: key, chunkCounter: nextChunkCounter, flags: flags)
            }

            let want = Blake3Constants.CHUNK_LEN - chunkState.totalLen
            let take = min(want, input.count - offset)
            // Pass the full array with offset/length to avoid slice-to-array copy
            chunkState.update(input, offset: offset, length: take)
            offset += take
        }
    }

    func finalOutput() -> Blake3Output {
        // Finalize the current (possibly partial) chunk
        var output = chunkState.output()

        // Merge with stacked chaining values right-to-left
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
