# Contributing

Guidelines for building, testing, and contributing to blake-hash.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| JDK | 21+ | Kotlin compilation target |
| Gradle | 8+ (wrapper provided) | Android build system |
| Kotlin | 2.3+ | Android source language (managed by Gradle) |
| Swift | 6.1+ | iOS source language |
| Xcode | 16.4+ | iOS builds and testing |

## Project Structure

```
blake-hash/
├── android/
│   ├── build.gradle.kts              # Root build config (Kotlin 2.3.0)
│   ├── settings.gradle.kts           # Project: "blake-hash", includes :lib
│   └── lib/
│       ├── build.gradle.kts          # Library build (JDK 21, JUnit 5)
│       └── src/
│           ├── main/kotlin/io/blake/hash/
│           │   ├── BLAKE2b.kt        # BLAKE2b public API
│           │   ├── BLAKE2s.kt        # BLAKE2s public API
│           │   ├── BLAKE2bp.kt       # BLAKE2bp public API
│           │   ├── BLAKE2sp.kt       # BLAKE2sp public API
│           │   ├── BLAKE3.kt         # BLAKE3 public API
│           │   └── internal/
│           │       ├── BLAKE2Core.kt  # BLAKE2 engine (shared by b/s/bp/sp)
│           │       └── BLAKE3Core.kt  # BLAKE3 compression and tree logic
│           └── test/kotlin/io/blake/hash/
│               ├── BLAKE2Test.kt      # Cross-algorithm tests
│               ├── BLAKE2bTest.kt     # BLAKE2b KAT vectors
│               ├── BLAKE2sTest.kt     # BLAKE2s KAT vectors
│               ├── BLAKE2bpTest.kt    # BLAKE2bp KAT vectors
│               ├── BLAKE2spTest.kt    # BLAKE2sp KAT vectors
│               └── BLAKE3Test.kt      # BLAKE3 all-mode vectors
├── ios/
│   ├── Package.swift                  # SPM config (Swift 6.1, platforms)
│   ├── Sources/BlakeHash/
│   │   ├── BLAKE2b.swift
│   │   ├── BLAKE2s.swift
│   │   ├── BLAKE2bp.swift
│   │   ├── BLAKE2sp.swift
│   │   ├── BLAKE3.swift
│   │   └── Internal/
│   │       ├── BLAKE2Core.swift
│   │       └── BLAKE3Core.swift
│   └── Tests/BlakeHashTests/
│       ├── BLAKE2bTests.swift
│       ├── BLAKE2sTests.swift
│       ├── BLAKE2bpTests.swift
│       ├── BLAKE2spTests.swift
│       ├── BLAKE3Tests.swift
│       ├── BLAKE3KeyedTests.swift
│       ├── BLAKE3XofTests.swift
│       ├── BLAKE3DeriveKeyTests.swift
│       └── CrossAlgorithmTests.swift
└── docs/
    ├── API.md
    ├── ALGORITHMS.md
    └── CONTRIBUTING.md                # This file
```

## Building

### Android

```bash
cd android
./gradlew build
```

If the Gradle wrapper is not present, use your system Gradle:

```bash
cd android
gradle build
```

### iOS

```bash
cd ios
swift build
```

## Testing

### Android

```bash
cd android
./gradlew test
```

Tests use JUnit 5 (Jupiter). Test reports are written to `lib/build/reports/tests/test/index.html`.

### iOS

```bash
cd ios
swift test
```

Tests use Swift Testing. All tests run on macOS; for device testing, open in Xcode.

### Verifying Both Platforms

From the repository root:

```bash
(cd android && ./gradlew test) && (cd ios && swift test)
```

You can also run `swift test` from the repository root (the root-level `Package.swift` works):

```bash
swift test
```

## Code Style

### Visibility

- **Public API surface:** `public` visibility on the algorithm types (`BLAKE2b`, `BLAKE2s`, etc.), their companion/static functions, and the `Hasher` types.
- **Internal engine code:** `internal` visibility (Kotlin) or no access modifier / `internal` (Swift) for `BLAKE2Core`, `BLAKE3Core`, and engine classes.
- **Private implementation:** `private` for constants, helper functions, and internal state.

### Naming

- Algorithm types are named `BLAKE2b`, `BLAKE2s`, `BLAKE2bp`, `BLAKE2sp`, `BLAKE3` (matching algorithm names).
- One-shot functions: `hash()`, `keyedHash()`, `deriveKey()`.
- Streaming type: `Hasher` (nested inside the algorithm type).
- Streaming methods: `update()`, `finalize()`, `finalizeXof()`.

### Kotlin

- Target JDK 21 via `jvmToolchain(21)`.
- Use `ByteArray` for all byte data.
- `@JvmOverloads` on `Hasher` constructors for Java interop.
- Fluent API: `update()` returns `this`.

### Swift

- Minimum Swift 6.1 (swift-tools-version: 6.1).
- Use `Data` for all byte data.
- All public types conform to `Sendable`.
- `update()` is `mutating` on value-type `Hasher`.

## Adding Test Vectors

Test vectors are embedded directly in test source files (no external JSON/text files). To add new vectors:

1. **Find or generate the vector.** Use the official reference implementations:
   - BLAKE2: [blake2.net](https://blake2.net) or RFC 7693 appendix
   - BLAKE3: [github.com/BLAKE3-team/BLAKE3](https://github.com/BLAKE3-team/BLAKE3) reference `test_vectors.json`

2. **Add to both platforms.** Every test vector must appear in both the Kotlin and Swift test suites so both implementations are verified against the same expected outputs.

3. **Use hex-encoded strings** for expected values to keep tests readable.

4. **Name tests descriptively:**
   ```kotlin
   // Kotlin
   @Test fun `hash empty input produces correct digest`() { ... }
   @Test fun `keyed hash with 64-byte key`() { ... }
   ```
   ```swift
   // Swift
   @Test func hashEmptyInput() { ... }
   @Test func keyedHashWith64ByteKey() { ... }
   ```

5. **Run both test suites** to confirm the vector passes on both platforms.

## Making Changes

1. **Create a feature branch** from `main`.
2. **Keep Kotlin and Swift in sync.** API changes must be mirrored on both platforms. The public APIs should remain identical in capability.
3. **Write tests first** for any new functionality or bug fix.
4. **Run the full test suite** on both platforms before pushing.
5. **Update documentation** if you change public API signatures.

## Pull Request Process

1. Ensure all tests pass on both Android and iOS.
2. Keep PRs focused — one feature or fix per PR.
3. Describe what changed and why in the PR description.
4. Reference any relevant issues.
5. Expect review feedback on both correctness and cross-platform consistency.
