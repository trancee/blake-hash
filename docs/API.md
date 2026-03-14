# API Reference

Complete API reference for **blake-hash** covering both Kotlin (Android) and Swift (iOS).

Package / module:
- **Kotlin:** `io.blake.hash`
- **Swift:** `BlakeHash`

---

## Table of Contents

- [Blake2b](#blake2b)
- [Blake2s](#blake2s)
- [Blake2bp](#blake2bp)
- [Blake2sp](#blake2sp)
- [Blake3](#blake3)

---

## Blake2b

BLAKE2b is the 64-bit variant of BLAKE2 (RFC 7693). It produces digests from 1 to 64 bytes and supports keyed hashing, salt, and personalization.

### One-Shot Hash

Hashes the entire input in a single call.

#### Kotlin

```kotlin
Blake2b.hash(
    input: ByteArray,
    digestLength: Int = 64,          // 1–64
    key: ByteArray = ByteArray(0),   // 0–64 bytes
    salt: ByteArray = ByteArray(0),  // 0–16 bytes
    personalization: ByteArray = ByteArray(0)  // 0–16 bytes
): ByteArray
```

#### Swift

```swift
Blake2b.hash(
    _ input: [UInt8],
    digestLength: Int = 64,          // 1–64
    key: [UInt8] = [],               // 0–64 bytes
    salt: [UInt8] = [],              // 0–16 bytes
    personalization: [UInt8] = []    // 0–16 bytes
) -> [UInt8]
```

#### Parameters

| Parameter | Type | Default | Constraints | Description |
|-----------|------|---------|-------------|-------------|
| `input` | byte array | — | any length | Data to hash |
| `digestLength` | int | 64 | 1–64 | Output length in bytes |
| `key` | byte array | empty | 0–64 bytes | Enables keyed (MAC) mode when non-empty |
| `salt` | byte array | empty | 0–16 bytes | Optional salt mixed into the state |
| `personalization` | byte array | empty | 0–16 bytes | Optional personalization string |

#### Examples

```kotlin
// Kotlin — default 64-byte hash
val hash = Blake2b.hash("abc".toByteArray())

// Kotlin — 32-byte keyed hash
val mac = Blake2b.hash(
    input = message,
    digestLength = 32,
    key = "my-secret-key".toByteArray()
)

// Kotlin — with salt and personalization
val h = Blake2b.hash(
    input = data,
    salt = "unique-salt12345".toByteArray(),           // 16 bytes
    personalization = "MyApp-v1________".toByteArray()  // 16 bytes
)
```

```swift
// Swift — default 64-byte hash
let hash = Blake2b.hash(Array("abc".utf8))

// Swift — 32-byte keyed hash
let mac = Blake2b.hash(
    Array(message),
    digestLength: 32,
    key: Array("my-secret-key".utf8)
)

// Swift — with salt and personalization
let h = Blake2b.hash(
    data,
    salt: Array("unique-salt12345".utf8),            // 16 bytes
    personalization: Array("MyApp-v1________".utf8)  // 16 bytes
)
```

### Streaming Hasher

Process data incrementally. Useful for large files or streamed input.

#### Kotlin

```kotlin
Blake2b.Hasher(
    digestLength: Int = 64,
    key: ByteArray = ByteArray(0),
    salt: ByteArray = ByteArray(0),
    personalization: ByteArray = ByteArray(0)
)
    .update(input: ByteArray): Hasher
    .update(input: ByteArray, offset: Int, length: Int): Hasher
    .finalize(): ByteArray
```

#### Swift

```swift
var hasher = Blake2b.Hasher(
    digestLength: Int = 64,
    key: [UInt8] = [],
    salt: [UInt8] = [],
    personalization: [UInt8] = []
)
hasher.update(_ input: [UInt8])
hasher.update(_ input: [UInt8], offset: Int, length: Int)
hasher.finalize() -> [UInt8]
```

#### Examples

```kotlin
// Kotlin — streaming hash
val hasher = Blake2b.Hasher(digestLength = 32)
hasher.update(chunk1)
hasher.update(chunk2)
val digest = hasher.finalize()

// Kotlin — streaming keyed hash
val keyedHasher = Blake2b.Hasher(key = secretKey)
keyedHasher.update(data)
val mac = keyedHasher.finalize()

// Kotlin — partial buffer update
hasher.update(buffer, offset = 10, length = 50)
```

```swift
// Swift — streaming hash
var hasher = Blake2b.Hasher(digestLength: 32)
hasher.update(chunk1)
hasher.update(chunk2)
let digest = hasher.finalize()

// Swift — streaming keyed hash
var keyedHasher = Blake2b.Hasher(key: secretKey)
keyedHasher.update(data)
let mac = keyedHasher.finalize()

// Swift — partial buffer update
hasher.update(buffer, offset: 10, length: 50)
```

> **Note:** In Kotlin, `update()` returns `self` for fluent chaining. In Swift, `update()` is a `mutating func` and returns `Void`.

---

## Blake2s

BLAKE2s is the 32-bit variant of BLAKE2 (RFC 7693). Optimized for 8- to 32-bit platforms. API mirrors Blake2b with smaller limits.

### One-Shot Hash

#### Kotlin

```kotlin
Blake2s.hash(
    input: ByteArray,
    digestLength: Int = 32,          // 1–32
    key: ByteArray = ByteArray(0),   // 0–32 bytes
    salt: ByteArray = ByteArray(0),  // 0–8 bytes
    personalization: ByteArray = ByteArray(0)  // 0–8 bytes
): ByteArray
```

#### Swift

```swift
Blake2s.hash(
    _ input: [UInt8],
    digestLength: Int = 32,          // 1–32
    key: [UInt8] = [],               // 0–32 bytes
    salt: [UInt8] = [],              // 0–8 bytes
    personalization: [UInt8] = []    // 0–8 bytes
) -> [UInt8]
```

#### Parameters

| Parameter | Type | Default | Constraints | Description |
|-----------|------|---------|-------------|-------------|
| `input` | byte array | — | any length | Data to hash |
| `digestLength` | int | 32 | 1–32 | Output length in bytes |
| `key` | byte array | empty | 0–32 bytes | Enables keyed (MAC) mode when non-empty |
| `salt` | byte array | empty | 0–8 bytes | Optional salt |
| `personalization` | byte array | empty | 0–8 bytes | Optional personalization string |

#### Examples

```kotlin
// Kotlin
val hash = Blake2s.hash("abc".toByteArray())
val mac = Blake2s.hash("abc".toByteArray(), key = secretKey)
```

```swift
// Swift
let hash = Blake2s.hash(Array("abc".utf8))
let mac = Blake2s.hash(Array("abc".utf8), key: secretKey)
```

### Streaming Hasher

#### Kotlin

```kotlin
Blake2s.Hasher(
    digestLength: Int = 32,
    key: ByteArray = ByteArray(0),
    salt: ByteArray = ByteArray(0),
    personalization: ByteArray = ByteArray(0)
)
    .update(input: ByteArray): Hasher
    .update(input: ByteArray, offset: Int, length: Int): Hasher
    .finalize(): ByteArray
```

#### Swift

```swift
var hasher = Blake2s.Hasher(
    digestLength: Int = 32,
    key: [UInt8] = [],
    salt: [UInt8] = [],
    personalization: [UInt8] = []
)
hasher.update(_ input: [UInt8])
hasher.update(_ input: [UInt8], offset: Int, length: Int)
hasher.finalize() -> [UInt8]
```

#### Examples

```kotlin
// Kotlin
val hasher = Blake2s.Hasher()
hasher.update(chunk1).update(chunk2)
val digest = hasher.finalize()
```

```swift
// Swift
var hasher = Blake2s.Hasher()
hasher.update(chunk1)
hasher.update(chunk2)
let digest = hasher.finalize()
```

---

## Blake2bp

BLAKE2bp is a 4-way parallel tree mode built on BLAKE2b. It distributes input across four BLAKE2b leaf instances in 512-byte superblocks, then merges them through a root BLAKE2b instance. Output is always 64 bytes.

### One-Shot Hash

#### Kotlin

```kotlin
Blake2bp.hash(
    input: ByteArray,
    key: ByteArray = ByteArray(0)  // 0–64 bytes
): ByteArray  // always 64 bytes
```

#### Swift

```swift
Blake2bp.hash(
    _ input: [UInt8],
    key: [UInt8] = []              // 0–64 bytes
) -> [UInt8]  // always 64 bytes
```

#### Parameters

| Parameter | Type | Default | Constraints | Description |
|-----------|------|---------|-------------|-------------|
| `input` | byte array | — | any length | Data to hash |
| `key` | byte array | empty | 0–64 bytes | Enables keyed mode when non-empty |

#### Examples

```kotlin
// Kotlin
val hash = Blake2bp.hash(largeData)
val mac = Blake2bp.hash(largeData, key = secretKey)
```

```swift
// Swift
let hash = Blake2bp.hash(largeData)
let mac = Blake2bp.hash(largeData, key: secretKey)
```

### Streaming Hasher

#### Kotlin

```kotlin
Blake2bp.Hasher(key: ByteArray = ByteArray(0))
    .update(input: ByteArray): Hasher
    .finalize(): ByteArray  // always 64 bytes
```

#### Swift

```swift
var hasher = Blake2bp.Hasher(key: [UInt8] = [])
hasher.update(_ input: [UInt8])
hasher.finalize() -> [UInt8]  // always 64 bytes
```

#### Examples

```kotlin
// Kotlin
val hasher = Blake2bp.Hasher()
hasher.update(chunk1).update(chunk2)
val digest = hasher.finalize()
```

```swift
// Swift
var hasher = Blake2bp.Hasher()
hasher.update(chunk1)
hasher.update(chunk2)
let digest = hasher.finalize()
```

> **Note:** BLAKE2bp produces different output than BLAKE2b for the same input. Use BLAKE2bp when you need the parallel tree structure; use BLAKE2b for standard RFC 7693 compatibility.

---

## Blake2sp

BLAKE2sp is an 8-way parallel tree mode built on BLAKE2s. It distributes input across eight BLAKE2s leaf instances in 512-byte superblocks, then merges them through a root BLAKE2s instance. Output is always 32 bytes.

### One-Shot Hash

#### Kotlin

```kotlin
Blake2sp.hash(
    input: ByteArray,
    key: ByteArray = ByteArray(0)  // 0–32 bytes
): ByteArray  // always 32 bytes
```

#### Swift

```swift
Blake2sp.hash(
    _ input: [UInt8],
    key: [UInt8] = []              // 0–32 bytes
) -> [UInt8]  // always 32 bytes
```

#### Parameters

| Parameter | Type | Default | Constraints | Description |
|-----------|------|---------|-------------|-------------|
| `input` | byte array | — | any length | Data to hash |
| `key` | byte array | empty | 0–32 bytes | Enables keyed mode when non-empty |

#### Examples

```kotlin
// Kotlin
val hash = Blake2sp.hash(largeData)
val mac = Blake2sp.hash(largeData, key = secretKey)
```

```swift
// Swift
let hash = Blake2sp.hash(largeData)
let mac = Blake2sp.hash(largeData, key: secretKey)
```

### Streaming Hasher

#### Kotlin

```kotlin
Blake2sp.Hasher(key: ByteArray = ByteArray(0))
    .update(input: ByteArray): Hasher
    .finalize(): ByteArray  // always 32 bytes
```

#### Swift

```swift
var hasher = Blake2sp.Hasher(key: [UInt8] = [])
hasher.update(_ input: [UInt8])
hasher.finalize() -> [UInt8]  // always 32 bytes
```

#### Examples

```kotlin
// Kotlin
val hasher = Blake2sp.Hasher(key = secretKey)
hasher.update(data)
val mac = hasher.finalize()
```

```swift
// Swift
var hasher = Blake2sp.Hasher(key: secretKey)
hasher.update(data)
let mac = hasher.finalize()
```

> **Note:** BLAKE2sp produces different output than BLAKE2s for the same input. It is designed for parallel hashing on 32-bit platforms.

---

## Blake3

BLAKE3 is a modern cryptographic hash function with three built-in modes: hash, keyed hash (MAC/PRF), and key derivation (KDF). It supports extendable output (XOF) for arbitrary-length digests.

### One-Shot Functions

#### `hash` — Unkeyed Hash

```kotlin
// Kotlin
Blake3.hash(input: ByteArray): ByteArray  // 32 bytes
```

```swift
// Swift
Blake3.hash(_ input: [UInt8]) -> [UInt8]  // 32 bytes
```

Returns a 32-byte digest. For variable-length output, use the streaming `Hasher` with `finalizeXof()`.

#### `keyedHash` — MAC / PRF

```kotlin
// Kotlin
Blake3.keyedHash(
    key: ByteArray,   // exactly 32 bytes
    input: ByteArray
): ByteArray  // 32 bytes
```

```swift
// Swift
Blake3.keyedHash(
    key: [UInt8],     // exactly 32 bytes
    data: [UInt8]
) -> [UInt8]  // 32 bytes
```

> **Key must be exactly 32 bytes.** This mode produces a keyed hash suitable for use as a message authentication code (MAC) or pseudorandom function (PRF).

#### `deriveKey` — Key Derivation

```kotlin
// Kotlin
Blake3.deriveKey(
    context: String,           // globally unique, hardcoded context string
    keyMaterial: ByteArray     // input key material
): ByteArray  // 32 bytes
```

```swift
// Swift
Blake3.deriveKey(
    context: String,           // globally unique, hardcoded context string
    keyMaterial: [UInt8]       // input key material
) -> [UInt8]  // 32 bytes
```

The `context` string should be a hardcoded, globally unique string that describes the application and purpose (e.g., `"myapp 2025-01-01 session-token"`). Never reuse a context string for different purposes.

#### One-Shot Examples

```kotlin
// Kotlin
val digest = Blake3.hash("Hello, world!".toByteArray())

val mac = Blake3.keyedHash(
    key = key32bytes,
    input = "message".toByteArray()
)

val derived = Blake3.deriveKey(
    context = "myapp 2025-01-01 session-token",
    keyMaterial = masterSecret
)
```

```swift
// Swift
let digest = Blake3.hash(Array("Hello, world!".utf8))

let mac = Blake3.keyedHash(
    key: key32bytes,
    data: Array("message".utf8)
)

let derived = Blake3.deriveKey(
    context: "myapp 2025-01-01 session-token",
    keyMaterial: masterSecret
)
```

### Streaming Hasher

The streaming `Hasher` supports all three modes and extendable output.

#### Construction

```kotlin
// Kotlin — hash mode (unkeyed)
val hasher = Blake3.Hasher()

// Kotlin — keyed hash mode
val keyedHasher = Blake3.Hasher(key = key32bytes)

// Kotlin — key derivation mode
val kdfHasher = Blake3.Hasher.deriveKey(context = "myapp 2025-01-01 session-token")
```

```swift
// Swift — hash mode (unkeyed)
var hasher = Blake3.Hasher()

// Swift — keyed hash mode
var keyedHasher = Blake3.Hasher(key: key32bytes)

// Swift — key derivation mode
var kdfHasher = Blake3.Hasher.deriveKey(context: "myapp 2025-01-01 session-token")
```

#### Updating

```kotlin
// Kotlin
hasher.update(input: ByteArray): Hasher
hasher.update(input: ByteArray, offset: Int, length: Int): Hasher
```

```swift
// Swift
hasher.update(_ input: [UInt8])
```

#### Finalizing

```kotlin
// Kotlin — 32-byte output
hasher.finalize(): ByteArray

// Kotlin — arbitrary-length output (XOF)
hasher.finalizeXof(outputLength: Int): ByteArray
```

```swift
// Swift — 32-byte output
hasher.finalize() -> [UInt8]

// Swift — arbitrary-length output (XOF)
hasher.finalizeXof(outputLength: Int) -> [UInt8]
```

#### Streaming Examples

```kotlin
// Kotlin — hash a file in chunks
val hasher = Blake3.Hasher()
inputStream.buffered().use { stream ->
    val buf = ByteArray(8192)
    var n: Int
    while (stream.read(buf).also { n = it } != -1) {
        hasher.update(buf, 0, n)
    }
}
val fileHash = hasher.finalize()

// Kotlin — XOF: generate 128 bytes of output
val xof = Blake3.Hasher()
    .apply { update("seed".toByteArray()) }
    .finalizeXof(128)

// Kotlin — streaming key derivation
val kdf = Blake3.Hasher.deriveKey("myapp 2025-01-01 encryption-key")
kdf.update(userPassword.toByteArray())
kdf.update(serverSalt)
val derivedKey = kdf.finalize()
```

```swift
// Swift — hash data in chunks
var hasher = Blake3.Hasher()
for chunk in dataChunks {
    hasher.update(chunk)
}
let fileHash = hasher.finalize()

// Swift — XOF: generate 128 bytes of output
var xofHasher = Blake3.Hasher()
xofHasher.update(Array("seed".utf8))
let xof = xofHasher.finalizeXof(outputLength: 128)

// Swift — streaming key derivation
var kdf = Blake3.Hasher.deriveKey(context: "myapp 2025-01-01 encryption-key")
kdf.update(Array(userPassword.utf8))
kdf.update(serverSalt)
let derivedKey = kdf.finalize()
```

### XOF (Extendable Output Function)

BLAKE3's `finalizeXof()` produces output of any requested length. The first 32 bytes of `finalizeXof(n)` are identical to `finalize()` — XOF simply extends the output beyond 32 bytes.

```kotlin
// Kotlin — the first 32 bytes match
val a = Blake3.Hasher().apply { update(data) }.finalize()            // 32 bytes
val b = Blake3.Hasher().apply { update(data) }.finalizeXof(32)       // 32 bytes
// a == b

val long = Blake3.Hasher().apply { update(data) }.finalizeXof(1024)  // 1024 bytes
// long[0..31] == a
```

```swift
// Swift — the first 32 bytes match
var h1 = Blake3.Hasher(); h1.update(data)
var h2 = Blake3.Hasher(); h2.update(data)
let a = h1.finalize()              // 32 bytes
let b = h2.finalizeXof(outputLength: 32)  // 32 bytes
// a == b
```

Use cases for XOF:
- Generating multiple keys from one seed
- Producing stream cipher keystreams
- Domain-separated key expansion
