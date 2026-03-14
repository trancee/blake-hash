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

| Algorithm   | v1 (MB/s) | v2 (MB/s) | v3 (MB/s)   | v2→v3 Change |
|-------------|-----------|-----------|-------------|--------------|
| BLAKE2b-512 | 287.02    | 712.04    | **1005.05** | **+41.2%**   |
| BLAKE2b-256 | 285.74    | 711.99    | **1006.99** | **+41.4%**   |
| BLAKE2s-256 | 181.56    | 513.73    | **703.90**  | **+37.0%**   |
| BLAKE2bp    | 275.68    | 668.66    | **980.63**  | **+46.6%**   |
| BLAKE2sp    | 175.35    | 506.42    | **684.24**  | **+35.1%**   |
| BLAKE3      | 224.28    | 618.03    | **800.30**  | **+29.5%**   |

> **v1:** Initial implementation (per-compress array allocation, separate g() method)
> **v2:** Pre-allocated CV stack, reduced intermediate copies in BLAKE3
> **v3:** Local-variable state vector, inlined G, flattened permutation tables, VarHandle LE loading

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

## v3 Optimizations — Low-level JVM (Kotlin)

### 12. Local-variable state vector in compression

**Files:** `Blake2b.kt`, `Blake2s.kt`, `Blake3Core.kt`

The compression function's 16-element working vector was stored in an
`IntArray`/`LongArray` — every access incurred a JVM bounds check. Replacing
the array with 16 local variables (`var v0..v15`) eliminates all bounds checks
and allows HotSpot to keep values in CPU registers:

```kotlin
// Before — array bounds check on every v[a], v[b], v[c], v[d]
val v = LongArray(16)
// ... fill from h[] and IV[]
g(v, 0, 4, 8, 12, m[s[0]], m[s[1]])

// After — local variables, zero bounds checks, register-eligible
var v0 = h[0]; var v1 = h[1]; /* ... */ var v15 = IV[7]
v0 += v4 + m[SIGMA_FLAT[s]]; v12 = (v12 xor v0).rotateRight(32)
v8 += v12; v4 = (v4 xor v8).rotateRight(24)
// ...
```

Each BLAKE2b compress call performs 768 v[] accesses (12 rounds × 8 G calls ×
8 reads/writes). Eliminating bounds checks on all of them is the single
biggest JVM optimization.

### 13. Inlined G mixing function

**Files:** `Blake2b.kt`, `Blake2s.kt`, `Blake3Core.kt`

The `g()` method was removed and its body inlined directly into the compression
loop. While HotSpot should inline small private methods, explicit inlining
guarantees:

- No method call overhead (even before JIT warm-up)
- JIT can see the full data flow for register allocation
- Array index parameters (a, b, c, d) become constants, enabling more
  aggressive optimization

The rotation amounts are now literal constants: `rotateRight(32)` instead of
a runtime parameter. `Long.rotateRight()` and `Int.rotateRight()` compile to
single `ROR` instructions on ARM64 and `ror` on x86-64.

### 14. Flattened permutation tables (Kotlin)

**Files:** `Blake2Core.kt`, `Blake3Core.kt`

Same approach as Swift (§10). The SIGMA table for BLAKE2 was
`Array<IntArray>` (10 rows × 16 elements) — two levels of array indirection.
Replaced with a flat `IntArray` of 160 elements indexed as
`SIGMA_FLAT[(round % 10) * 16 + i]`:

```kotlin
// Before — nested arrays, 2 bounds-checked array accesses per lookup
val SIGMA = arrayOf(intArrayOf(0, 1, 2, ...), intArrayOf(14, 10, 4, ...), ...)
val s = SIGMA[round % 10]; g(v, 0, 4, 8, 12, m[s[0]], m[s[1]])

// After — flat array, single bounds-checked access
@JvmField val SIGMA_FLAT = intArrayOf(0, 1, 2, ..., 14, 10, 4, ...)
v0 += v4 + m[SIGMA_FLAT[s + 0]]
```

`@JvmField` avoids the Kotlin property getter, exposing the array as a direct
static field. BLAKE3's `MSG_SCHEDULE` (`Array<IntArray>`) was similarly
flattened to `MSG_PERM`.

### 15. VarHandle-based little-endian word loading

**File:** `Blake2Core.kt`, `Blake3Core.kt`

The original `loadLong` assembled 8 bytes one at a time — 8 array accesses
with bounds checks, 8 `toLong()` + mask operations, and 7 shifts. Replaced
with `java.lang.invoke.VarHandle` which HotSpot intrinsifies to a single
unaligned memory load:

```kotlin
// Before — 8 bounds-checked byte reads + 7 shifts per word
internal fun loadLong(src: ByteArray, off: Int): Long =
    (src[off].toLong() and 0xFFL) or
    ((src[off + 1].toLong() and 0xFFL) shl 8) or
    // ... 6 more lines

// After — single unaligned load instruction on LE platforms
val LONG_LE = MethodHandles.byteArrayViewVarHandle(
    LongArray::class.java, ByteOrder.LITTLE_ENDIAN)
internal fun loadLong(src: ByteArray, off: Int): Long =
    LONG_LE.get(src, off) as Long
```

On little-endian platforms (x86-64 and ARM64), `VarHandle.get()` compiles
to a single `LDR`/`MOV` instruction — no byte swapping needed. For BLAKE2b,
this eliminates 16 × 7 = 112 redundant byte accesses per compress call.

`loadInt`/`storeInt` for BLAKE2s and BLAKE3 use the same approach via
`INT_LE` VarHandle. Requires JDK 9+ (project targets JDK 21).

### 16. Pre-allocated message word array

**Files:** `Blake2b.kt`, `Blake2s.kt`

The message word array `m` was moved from a local allocation in `compress()`
to a pre-allocated instance field:

```kotlin
// Before — allocated on every compress call
private fun compress(...) {
    val m = LongArray(16)
    // ...
}

// After — reused across calls
private val m = LongArray(16)
private fun compress(...) {
    for (i in 0..15) m[i] = loadLong(block, off + i * 8)
    // ...
}
```

While HotSpot's escape analysis can stack-allocate local arrays, pre-allocation
removes the allocation path entirely and avoids the array zeroing cost.

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
- **All tests pass** after optimization (77 Swift tests, 282 Kotlin tests)
