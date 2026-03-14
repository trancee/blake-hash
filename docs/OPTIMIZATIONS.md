# Performance Optimizations

Summary of performance refactoring applied to the blake-hash library, with
before/after throughput measurements on 1 MB payloads.

---

## Benchmark Results

### Swift (release build, Apple Silicon)

| Algorithm   | Before (MB/s) | After (MB/s) | Change  |
|-------------|---------------|--------------|---------|
| BLAKE2b-512 | 472.63        | 724.90       | **+53.4%** |
| BLAKE2b-256 | 476.41        | 727.57       | **+52.7%** |
| BLAKE2s-256 | 271.64        | 476.53       | **+75.4%** |
| BLAKE2bp    | 442.98        | 649.39       | **+46.6%** |
| BLAKE2sp    | 253.49        | 426.78       | **+68.4%** |
| BLAKE3      | 226.51        | 466.86       | **+106.1%** |

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

## Methodology

- **Data size:** 1 MB per hash
- **Kotlin:** 50 warm-up iterations, 200 timed iterations (JUnit + Gradle)
- **Swift:** 20 warm-up iterations, 100 timed iterations (Swift Testing, release build)
- **Hardware:** Apple Silicon (arm64)
- **All tests pass** after optimization (77 Swift tests, full Kotlin suite)
