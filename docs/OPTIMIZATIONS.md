# Performance Optimizations

Summary of performance refactoring applied to the blake-hash library, with
before/after throughput measurements on 1 MB payloads.

---

## Benchmark Results

### Swift (release build, Apple Silicon)

| Algorithm   | v1 (MB/s) | v2 (MB/s) | v3 (MB/s)  | v2→v3 Change |
|-------------|-----------|-----------|------------|--------------|
| BLAKE2b-512 | 472.63    | 724.90    | **1284.05** | **+77.1%**   |
| BLAKE2b-256 | 476.41    | 727.57    | **1288.19** | **+77.1%**   |
| BLAKE2s-256 | 271.64    | 476.53    | **777.83**  | **+63.2%**   |
| BLAKE2bp    | 442.98    | 649.39    | **1207.40** | **+85.9%**   |
| BLAKE2sp    | 253.49    | 426.78    | **750.37**  | **+75.8%**   |
| BLAKE3      | 226.51    | 466.86    | **640.14**  | **+37.1%**   |

> **v1:** Initial implementation (heap arrays, generic G function)
> **v2:** Pre-allocated working arrays, in-place compression
> **v3:** Unsafe pointer access, specialized G functions, `loadUnaligned` LE loading

### Kotlin/JVM (HotSpot, Apple Silicon)

| Algorithm   | Before (MB/s) | After (MB/s) | Change |
|-------------|---------------|--------------|--------|
| BLAKE2b-512 | 705.48        | 712.04       | +0.9%  |
| BLAKE2b-256 | 700.71        | 711.99       | +1.6%  |
| BLAKE2s-256 | 515.51        | 513.73       | −0.3%  |
| BLAKE2bp    | 680.31        | 668.66       | −1.7%  |
| BLAKE2sp    | 508.58        | 506.42       | −0.4%  |
| BLAKE3      | 607.17        | 618.03       | +1.8%  |

> Kotlin BLAKE2b/BLAKE2s numbers are within normal JVM benchmark variance
> (±2%). HotSpot's JIT already optimizes local array allocations via escape
> analysis, so the main Kotlin gain is in BLAKE3's tree management.

---

## What Changed

### 1. Pre-allocated compression working arrays (Swift)

**Files:** `Blake2Core.swift`, `Blake3Core.swift`

The compression function is called once per block — roughly 8,000 times for a
1 MB BLAKE2b hash. The original code allocated fresh `m` (message words) and
`v` (state vector) arrays on every call:

```swift
// Before — allocates 2 × [UInt32/UInt64](count: 16) per block
var m = [V.Word](repeating: 0, count: 16)
var v = [V.Word](repeating: 0, count: 16)
```

Each allocation involves heap allocation + ARC overhead. Moving these to
pre-allocated instance fields on `Blake2Engine` eliminates thousands of
allocations per hash:

```swift
// After — reuse instance fields
private var v: [V.Word]
private var m: [V.Word]
```

The compression function signature was updated to accept `inout` references:

```swift
func blake2Compress<V>(..., v: inout [V.Word], m: inout [V.Word])
```

**Impact:** This single change accounts for the majority of the 50–75%
improvement on BLAKE2b and BLAKE2s.

### 2. In-place BLAKE3 compression (Swift)

**File:** `Blake3Core.swift`

Added `blake3CompressInto()` that writes directly into a pre-allocated output
array instead of allocating a new 16-word array on every call:

```swift
// Before — allocates [UInt32](count: 16) per compression
func blake3Compress(...) -> [UInt32]

// After — writes into caller's buffer
func blake3CompressInto(..., out: inout [UInt32])
```

`Blake3ChunkState` now holds pre-allocated `blockWords` and `compressOut`
arrays, and `Blake3Output.rootOutputBytes()` reuses a single `compressOut`
buffer across XOF counter blocks.

**Impact:** Combined with the `wordsFromBytes` elimination (below), this
produces the 106% improvement on BLAKE3.

### 3. Eliminated `wordsFromBytes` allocations in BLAKE3 (Swift)

**File:** `Blake3Core.swift`

`Blake3ChunkState.update()` previously called `wordsFromBytes(block)` on every
full-block compression, allocating a new `[UInt32]` each time. Replaced with
inline little-endian word loading into the pre-allocated `blockWords` array:

```swift
// Before
let blockWords = wordsFromBytes(block)

// After
for i in 0..<16 { blockWords[i] = loadLE32(block, at: i * 4) }
```

Similarly, `output()` now builds words in-place with partial-block handling
instead of calling `wordsFromBytes` on the full 64-byte block buffer.

### 4. Replaced element-by-element copy loops (Swift)

**Files:** `Blake2Core.swift`, `Blake2bp.swift`, `Blake2sp.swift`,
`Blake3Core.swift`

Manual byte-copy loops were replaced with `Array.replaceSubrange` which the
Swift compiler can lower to `memcpy`:

```swift
// Before
for i in 0..<toCopy { buffer[bufferLength + i] = input[offset + i] }

// After
buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                       with: input[offset..<(offset + toCopy)])
```

### 5. Fixed-size CV stack for BLAKE3 tree (Kotlin)

**File:** `Blake3.kt`

Replaced `ArrayList<IntArray>` with a pre-allocated `Array(54) { IntArray(8) }`
and a manual length counter. This eliminates ArrayList's internal array
resizing, bounds checking, and object boxing:

```kotlin
// Before
private val cvStack = ArrayList<IntArray>(54)
cvStack.add(cv)
val right = cvStack.removeAt(cvStack.lastIndex)

// After
private val cvStack = Array(54) { IntArray(8) }
private var cvStackLen = 0
cv.copyInto(cvStack[cvStackLen]); cvStackLen++
```

### 6. Reduced intermediate copies in BLAKE3 Output (Kotlin)

**File:** `Blake3Core.kt`

- `chainingValueWords()` now returns from a pre-allocated `cvOut` array
  instead of `compressOut.copyOfRange(0, 8)` which allocated a new array
- `parentOutput()` uses a pre-allocated `parentBlockWords` scratch array
  instead of allocating `IntArray(16)` on every parent merge

---

## v3 Optimizations — Unsafe Pointer Access (Swift)

### 7. Unsafe pointer–based compression functions

**Files:** `Blake2Core.swift`, `Blake3Core.swift`

The compression function is the hottest code path — called ~8,000 times for a
1 MB BLAKE2b hash, with each call performing hundreds of array element
accesses. Swift's `Array` subscript inserts bounds checks on every access.
Wrapping the entire compression body in `withUnsafeMutableBufferPointer` /
`withUnsafeBufferPointer` eliminates all bounds checking from the inner loops:

```swift
// Before — every v[i], m[i], h[i] is bounds-checked
for round in 0..<12 {
    let s = blake2Sigma[round % 10]
    blake2G(&v, 0, 4, 8, 12, m[s[0]], m[s[1]], r1: V.r1, ...)
}

// After — raw pointer access, zero bounds checks
h.withUnsafeMutableBufferPointer { hBuf in
    v.withUnsafeMutableBufferPointer { vBuf in
        m.withUnsafeBufferPointer { mBuf in
            let hp = hBuf.baseAddress!
            let vp = vBuf.baseAddress!
            let mp = mBuf.baseAddress!
            for round in 0..<12 {
                let s = sp + (round % 10) * 16
                blake2bG(vp, 0, 4, 8, 12, mp[s[0]], mp[s[1]])
                // ...
            }
            for i in 0..<8 { hp[i] ^= vp[i] ^ vp[i + 8] }
        }
    }
}
```

### 8. Specialized G mixing functions with hardcoded rotations

**Files:** `Blake2Core.swift`, `Blake3Core.swift`

The original generic `blake2G<W>` function passed rotation constants as runtime
parameters via the `Blake2Variant` protocol. This prevented the compiler from
emitting single-instruction rotates. Replaced with dedicated functions per
variant that use `UnsafeMutablePointer` and compile-time constant rotations:

```swift
// Before — generic, runtime rotation amounts, Array bounds checks
func blake2G<W: FixedWidthInteger & UnsignedInteger>(
    _ v: inout [W], _ a: Int, _ b: Int, _ c: Int, _ d: Int,
    _ x: W, _ y: W, r1: Int, r2: Int, r3: Int, r4: Int)

// After — concrete type, constant rotations, raw pointer access
func blake2bG(
    _ v: UnsafeMutablePointer<UInt64>,
    _ a: Int, _ b: Int, _ c: Int, _ d: Int,
    _ x: UInt64, _ y: UInt64) {
    v[a] = v[a] &+ v[b] &+ x
    var tmp = v[d] ^ v[a]
    v[d] = (tmp &>> 32) | (tmp &<< 32)  // constant → single ROR instruction
    // ...
}
```

Three specialized G functions: `blake2bG` (UInt64, rotations 32/24/16/63),
`blake2sG` (UInt32, rotations 16/12/8/7), and `blake3G` (UInt32, rotations
16/12/8/7). The `Blake2Variant` protocol now includes a `compress` static
method so the generic `Blake2Engine` dispatches to the correct specialized
implementation.

### 9. Single-instruction LE word loading via `loadUnaligned`

**Files:** `Blake2Core.swift`, `Blake3Core.swift`

The original `blake2LoadLE<W>` used a generic byte-by-byte loop — 8 iterations
with 8 bounds-checked array accesses for each UInt64 word. Replaced with
`UnsafeRawPointer.loadUnaligned(as:)` which compiles to a single `LDR`
instruction on ARM64:

```swift
// Before — 8 iterations, 8 bounds checks per word
func blake2LoadLE<W: FixedWidthInteger>(_ bytes: [UInt8], offset: Int) -> W {
    var value = W.zero
    for i in 0..<(W.bitWidth / 8) {
        value |= W(truncatingIfNeeded: bytes[offset + i]) &<< (i * 8)
    }
    return value
}

// After — single unaligned load instruction
mp[i] = UInt64(littleEndian:
    bp.loadUnaligned(fromByteOffset: blockOffset + i * 8, as: UInt64.self))
```

`UInt64(littleEndian:)` is a no-op on little-endian platforms (all Apple
hardware). This alone eliminates ~128 bounds-checked byte reads per BLAKE2b
compression call.

### 10. Flattened permutation tables

**Files:** `Blake2Core.swift`, `Blake3Core.swift`

The SIGMA / MSG_PERMUTATION tables were stored as `[[Int]]` (array of arrays).
Each access involved two levels of indirection: outer array bounds check →
inner array reference → inner array bounds check → element. Flattened to a
single `[Int]` indexed as `sigma[round * 16 + i]`:

```swift
// Before — nested arrays, 2 levels of indirection
let blake2Sigma: [[Int]] = [[ 0, 1, 2, ...], [14, 10, 4, ...], ...]
let s = blake2Sigma[round % 10]  // inner array lookup
blake2G(..., m[s[0]], m[s[1]])   // element lookup

// After — flat array, single level via unsafe pointer
let blake2SigmaFlat: [Int] = [0, 1, 2, ..., 14, 10, 4, ..., ...]
let s = sp + (round % 10) * 16   // pointer arithmetic
blake2bG(..., mp[s[0]], mp[s[1]])
```

### 11. Pointer-based buffer copies

**Files:** `Blake2Core.swift`, `Blake3Core.swift`

Replaced `Array.replaceSubrange` and byte-loop copies with direct
`UnsafeRawPointer.copyMemory` for buffer operations:

```swift
// Before
buffer.replaceSubrange(bufferLength..<(bufferLength + toCopy),
                       with: input[inputOffset..<(inputOffset + toCopy)])

// After
buffer.withUnsafeMutableBytes { bufRaw in
    input.withUnsafeBytes { inputRaw in
        (bufRaw.baseAddress! + bl).copyMemory(
            from: inputRaw.baseAddress! + inputOffset, byteCount: toCopy)
    }
}
```

Also applied to `finalize()` output conversion — the hash state is now copied
directly to bytes via `copyMemory` instead of per-word `blake2StoreLE` calls.

---

## Why Kotlin Shows Less Improvement

HotSpot JVM's C2 JIT compiler applies **escape analysis** to local array
allocations. When it determines an array doesn't escape the method (as with
`val v = LongArray(16)` inside `compress()`), it can:

1. Allocate the array on the stack instead of the heap
2. Eliminate array bounds checks
3. Scalar-replace individual elements

This means the "allocate every call" pattern in the original Kotlin code was
already being optimized to near-zero cost by the JIT. Pre-allocating these
arrays as instance fields would actually regress performance by forcing heap
allocation and preventing escape analysis.

Swift has no equivalent optimization — array allocations always hit the heap
and involve ARC reference counting, making pre-allocation dramatically
beneficial.

> **Note:** On Android's ART runtime (the primary target for the Kotlin code),
> escape analysis is less sophisticated than HotSpot's. The BLAKE3 tree
> management optimizations (fixed-size CV stack, reduced copies) apply on both
> runtimes.

---

## Safety Analysis — Unsafe Pointer Access (Swift)

The v3 Swift optimizations replace bounds-checked `Array` subscripts with raw
pointer access via `withUnsafeMutableBufferPointer` / `withUnsafeBufferPointer`.
This section documents why this is safe despite the absence of runtime bounds
checks.

### Why out-of-bounds access is structurally impossible

All pointer-indexed arrays have **fixed, spec-defined sizes**:

| Array | Size | Indexed by |
|-------|------|------------|
| `h` (state) | 8 words | `0..<8` (constant) |
| `v` (work vector) | 16 words | `0..<16` (constant), G function args `{0–15}` |
| `m` (message words) | 16 words | `0..<16` (constant), sigma table values `{0–15}` |
| sigma / permutation | 10×16 flat | `(round % 10) * 16 + {0..15}` |
| block buffer | 64 or 128 bytes | `blockOffset + i * wordSize`, bounded by block size |

Every index is either a compile-time constant or derived from a bounded
calculation. No user input influences index values — only the *data* loaded
through those indices comes from external input.

### Containment measures

1. **Scoped pointers** — all unsafe access occurs inside `withUnsafe*` closures.
   Pointers cannot escape to instance state or be stored beyond the closure
   lifetime.

2. **Internal visibility** — the unsafe functions (`blake2bG`, `blake2sG`,
   `blake3G`, `blake2bCompressImpl`, `blake2sCompressImpl`,
   `blake3CompressInto`) are all `private` or `internal`. The public API
   (`Blake2b`, `Blake2s`, `Blake3`) validates inputs via preconditions before
   any unsafe code runs.

3. **`min()` guards on copies** — every `copyMemory` call caps `byteCount`
   with `min()` to prevent overruns (e.g., `min(remaining, V.blockSize -
   bufferLength)`).

4. **Force-unwrap safety** — `baseAddress!` is used on arrays that are
   pre-allocated to non-zero fixed sizes, so `baseAddress` is never `nil`.

### Risk summary

| Risk | Severity | Mitigation |
|------|----------|------------|
| Out-of-bounds read/write | Low | All indices are constants matching spec-defined array sizes |
| `baseAddress!` on empty array | Low | Arrays are pre-allocated to fixed non-zero sizes |
| `loadUnaligned` misuse | None | Correctly used for little-endian word loads |
| `copyMemory` overrun | Low | `min()` guards cap byte counts at every call site |
| No compiler bounds-check safety net | Accepted | Tradeoff for ~77% throughput gain in compression |

### Validation

The test suite (83 tests across 11 files) verifies all hash outputs against
known test vectors from the BLAKE2 RFC and BLAKE3 reference implementation. Any
pointer arithmetic error would produce incorrect hashes and be caught
immediately. This is the same assurance model used by production cryptographic
libraries (libsodium, CryptoKit, BoringSSL).

### Conclusion

Dropping bounds checks in the compression inner loops is a **standard
optimization for cryptographic hash implementations**. The fixed-size,
spec-driven nature of BLAKE compression makes out-of-bounds access structurally
impossible given correct constants. The optimization is safe to use as long as
the test vector suite continues to pass.

---

## Methodology

- **Data size:** 1 MB per hash
- **Kotlin:** 50 warm-up iterations, 200 timed iterations (JUnit + Gradle)
- **Swift:** 20 warm-up iterations, 100 timed iterations (Swift Testing, release build)
- **Hardware:** Apple Silicon (arm64)
- **All tests pass** after optimization (83 Swift tests, full Kotlin suite)
