# blake-hash

**Pure-implementation BLAKE cryptographic hash library for Android (Kotlin) and iOS (Swift).**

Zero external dependencies. Covers BLAKE2b, BLAKE2s, BLAKE2bp, BLAKE2sp, and BLAKE3 with all modes: hash, keyed hash (MAC), key derivation (KDF), and extendable output (XOF).

> **Swift 6.1+** · **Kotlin 2.3+** · **JDK 21+** · **iOS 17+ / macOS 14+**

---

## Features

- **Five BLAKE algorithms** — BLAKE2b, BLAKE2s, BLAKE2bp, BLAKE2sp, BLAKE3
- **All modes** — unkeyed hash, keyed hash (MAC/PRF), key derivation (KDF), extendable output (XOF)
- **Streaming API** — incremental `Hasher` for every algorithm
- **Zero dependencies** — pure Kotlin and pure Swift; no platform crypto, no native code
- **Thread-safe** — all Swift types are `Sendable`
- **Identical APIs** — Kotlin and Swift surfaces mirror each other

## Algorithm Overview

| Algorithm | Word Size | Digest | Key | Parallelism | Rounds | Salt / Personalization |
|-----------|-----------|--------|-----|-------------|--------|------------------------|
| BLAKE2b   | 64-bit    | 1–64 B | 0–64 B | 1         | 12     | ✅ (16 B each)         |
| BLAKE2s   | 32-bit    | 1–32 B | 0–32 B | 1         | 10     | ✅ (8 B each)          |
| BLAKE2bp  | 64-bit    | 64 B   | 0–64 B | 4-way     | 12     | —                      |
| BLAKE2sp  | 32-bit    | 32 B   | 0–32 B | 8-way     | 10     | —                      |
| BLAKE3    | 32-bit    | 32 B*  | 32 B   | Unbounded | 7      | —                      |

\* BLAKE3 supports arbitrary output length via XOF.

## Installation

### Android (Gradle — Kotlin DSL)

Add the library module to your project, or copy the source files under `blake.hash` into your app:

```kotlin
// settings.gradle.kts
include(":blake-hash")
project(":blake-hash").projectDir = file("path/to/blake-hash/android/lib")

// app/build.gradle.kts
dependencies {
    implementation(project(":blake-hash"))
}
```

### iOS (Swift Package Manager)

Add the local package or a Git dependency in Xcode or `Package.swift`:

```swift
// Package.swift
dependencies: [
    .package(path: "../blake-hash/ios")
    // or: .package(url: "https://github.com/trancee/blake-hash.git", from: "1.0.0")
]
```

Then import the module:

```swift
import BlakeHash
```

## Quick Start

### Kotlin

```kotlin
import blake.hash.Blake2b
import blake.hash.Blake3

// BLAKE2b — one-shot hash
val digest = Blake2b.hash("Hello".toByteArray())

// BLAKE2b — keyed hash (MAC)
val mac = Blake2b.hash("Hello".toByteArray(), key = secretKey)

// BLAKE2b — streaming
val hasher = Blake2b.Hasher()
hasher.update(chunk1)
hasher.update(chunk2)
val result = hasher.finalize()

// BLAKE3 — one-shot hash
val b3 = Blake3.hash("Hello".toByteArray())

// BLAKE3 — keyed hash (MAC)
val b3mac = Blake3.keyedHash(key32, "Hello".toByteArray())

// BLAKE3 — key derivation
val derived = Blake3.deriveKey("myapp 2025-01-01", keyMaterial)

// BLAKE3 — XOF (extended output)
val xof = Blake3.Hasher().apply { update("Hello".toByteArray()) }.finalizeXof(128)
```

### Swift

```swift
import BlakeHash

// BLAKE2b — one-shot hash
let digest = Blake2b.hash(Array("Hello".utf8))

// BLAKE2b — keyed hash (MAC)
let mac = Blake2b.hash(Array("Hello".utf8), key: secretKey)

// BLAKE2b — streaming
var hasher = Blake2b.Hasher()
hasher.update(chunk1)
hasher.update(chunk2)
let result = hasher.finalize()

// BLAKE3 — one-shot hash
let b3 = Blake3.hash(Array("Hello".utf8))

// BLAKE3 — keyed hash (MAC)
let b3mac = Blake3.keyedHash(key: key32, data: Array("Hello".utf8))

// BLAKE3 — key derivation
let derived = Blake3.deriveKey(context: "myapp 2025-01-01", keyMaterial: km)

// BLAKE3 — XOF (extended output)
var xofHasher = Blake3.Hasher()
xofHasher.update(Array("Hello".utf8))
let xof = xofHasher.finalizeXof(outputLength: 128)
```

## Documentation

| Document | Description |
|----------|-------------|
| [API Reference](docs/API.md) | Full API for Kotlin and Swift — every function, every parameter |
| [Algorithm Guide](docs/ALGORITHMS.md) | Which algorithm to choose, security levels, performance notes |
| [Release Process](docs/RELEASE.md) | How to publish a new version to Maven Central and GitHub Releases |
| [Contributing](docs/CONTRIBUTING.md) | Build, test, code style, PR process |

## License

See [LICENSE](LICENSE) for details.
