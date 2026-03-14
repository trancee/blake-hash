# API Reference

Complete API reference for **blake-hash** covering both Kotlin (Android) and Swift (iOS).

Package / module:
- **Kotlin:** `blake.hash`
- **Swift:** `BlakeHash`

---

## Table of Contents

- [BLAKE2b](#blake2b)
- [BLAKE2s](#blake2s)
- [BLAKE2bp](#blake2bp)
- [BLAKE2sp](#blake2sp)
- [BLAKE3](#blake3)

---

## BLAKE2b

BLAKE2b is the 64-bit variant of BLAKE2 (RFC 7693). It produces digests from 1 to 64 bytes and supports keyed hashing, salt, and personalization.

### One-Shot Hash

Hashes the entire input in a single call.

#### Kotlin

```kotlin
BLAKE2b.hash(
    input: ByteArray,
    digestLength: Int = 64,          // 1–64
    key: ByteArray = ByteArray(0),   // 0–64 bytes
    salt: ByteArray = ByteArray(0),  // 0–16 bytes
    personalization: ByteArray = ByteArray(0)  // 0–16 bytes
): ByteArray
```

#### Swift

```swift
BLAKE2b.hash(
    _ input: Data,
    digestLength: Int = 64,          // 1–64
    key: Data = Data(),              // 0–64 bytes
    salt: Data = Data(),             // 0–16 bytes
    personalization: Data = Data()   // 0–16 bytes
) -> Data
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
val hash = BLAKE2b.hash("abc".toByteArray())

// Kotlin — 32-byte keyed hash
val mac = BLAKE2b.hash(
    input = message,
    digestLength = 32,
    key = "my-secret-key".toByteArray()
)

// Kotlin — with salt and personalization
val h = BLAKE2b.hash(
    input = data,
    salt = "unique-salt12345".toByteArray(),           // 16 bytes
    personalization = "MyApp-v1________".toByteArray()  // 16 bytes
)
```

```swift
// Swift — default 64-byte hash
let hash = BLAKE2b.hash(Data("abc".utf8))

// Swift — 32-byte keyed hash
let mac = BLAKE2b.hash(
    Data(message),
    digestLength: 32,
    key: Data("my-secret-key".utf8)
)

// Swift — with salt and personalization
let h = BLAKE2b.hash(
    data,
    salt: Data("unique-salt12345".utf8),            // 16 bytes
    personalization: Data("MyApp-v1________".utf8)  // 16 bytes
)
```

### Streaming Hasher

Process data incrementally. Useful for large files or streamed input.

#### Kotlin

```kotlin
BLAKE2b.Hasher(
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
var hasher = BLAKE2b.Hasher(
    digestLength: Int = 64,
    key: Data = Data(),
    salt: Data = Data(),
    personalization: Data = Data()
)
hasher.update(_ input: Data)
hasher.update(_ input: Data, offset: Int, length: Int)
hasher.finalize() -> Data
```

#### Examples

```kotlin
// Kotlin — streaming hash
val hasher = BLAKE2b.Hasher(digestLength = 32)
hasher.update(chunk1)
hasher.update(chunk2)
val digest = hasher.finalize()

// Kotlin — streaming keyed hash
val keyedHasher = BLAKE2b.Hasher(key = secretKey)
keyedHasher.update(data)
val mac = keyedHasher.finalize()

// Kotlin — partial buffer update
hasher.update(buffer, offset = 10, length = 50)
```

```swift
// Swift — streaming hash
var hasher = BLAKE2b.Hasher(digestLength: 32)
hasher.update(chunk1)
hasher.update(chunk2)
let digest = hasher.finalize()

// Swift — streaming keyed hash
var keyedHasher = BLAKE2b.Hasher(key: secretKey)
keyedHasher.update(data)
let mac = keyedHasher.finalize()

// Swift — partial buffer update
hasher.update(buffer, offset: 10, length: 50)
```

> **Note:** In Kotlin, `update()` returns `self` for fluent chaining. In Swift, `update()` is a `mutating func` and returns `Void`.

---

## BLAKE2s

BLAKE2s is the 32-bit variant of BLAKE2 (RFC 7693). Optimized for 8- to 32-bit platforms. API mirrors BLAKE2b with smaller limits.

### One-Shot Hash

#### Kotlin

```kotlin
BLAKE2s.hash(
    input: ByteArray,
    digestLength: Int = 32,          // 1–32
    key: ByteArray = ByteArray(0),   // 0–32 bytes
    salt: ByteArray = ByteArray(0),  // 0–8 bytes
    personalization: ByteArray = ByteArray(0)  // 0–8 bytes
): ByteArray
```

#### Swift

```swift
BLAKE2s.hash(
    _ input: Data,
    digestLength: Int = 32,          // 1–32
    key: Data = Data(),              // 0–32 bytes
    salt: Data = Data(),             // 0–8 bytes
    personalization: Data = Data()   // 0–8 bytes
) -> Data
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
val hash = BLAKE2s.hash("abc".toByteArray())
val mac = BLAKE2s.hash("abc".toByteArray(), key = secretKey)
```

```swift
// Swift
let hash = BLAKE2s.hash(Data("abc".utf8))
let mac = BLAKE2s.hash(Data("abc".utf8), key: secretKey)
```

### Streaming Hasher

#### Kotlin

```kotlin
BLAKE2s.Hasher(
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
var hasher = BLAKE2s.Hasher(
    digestLength: Int = 32,
    key: Data = Data(),
    salt: Data = Data(),
    personalization: Data = Data()
)
hasher.update(_ input: Data)
hasher.update(_ input: Data, offset: Int, length: Int)
hasher.finalize() -> Data
```

#### Examples

```kotlin
// Kotlin
val hasher = BLAKE2s.Hasher()
hasher.update(chunk1).update(chunk2)
val digest = hasher.finalize()
```

```swift
// Swift
var hasher = BLAKE2s.Hasher()
hasher.update(chunk1)
hasher.update(chunk2)
let digest = hasher.finalize()
```

---

## BLAKE2bp

BLAKE2bp is a 4-way parallel tree mode built on BLAKE2b. It distributes input across four BLAKE2b leaf instances in 512-byte superblocks, then merges them through a root BLAKE2b instance. Output is always 64 bytes.

### One-Shot Hash

#### Kotlin

```kotlin
BLAKE2bp.hash(
    input: ByteArray,
    key: ByteArray = ByteArray(0)  // 0–64 bytes
): ByteArray  // always 64 bytes
```

#### Swift

```swift
BLAKE2bp.hash(
    _ input: Data,
    key: Data = Data()               // 0–64 bytes
) -> Data  // always 64 bytes
```

#### Parameters

| Parameter | Type | Default | Constraints | Description |
|-----------|------|---------|-------------|-------------|
| `input` | byte array | — | any length | Data to hash |
| `key` | byte array | empty | 0–64 bytes | Enables keyed mode when non-empty |

#### Examples

```kotlin
// Kotlin
val hash = BLAKE2bp.hash(largeData)
val mac = BLAKE2bp.hash(largeData, key = secretKey)
```

```swift
// Swift
let hash = BLAKE2bp.hash(largeData)
let mac = BLAKE2bp.hash(largeData, key: secretKey)
```

### Streaming Hasher

#### Kotlin

```kotlin
BLAKE2bp.Hasher(key: ByteArray = ByteArray(0))
    .update(input: ByteArray): Hasher
    .finalize(): ByteArray  // always 64 bytes
```

#### Swift

```swift
var hasher = BLAKE2bp.Hasher(key: Data = Data())
hasher.update(_ input: Data)
hasher.finalize() -> Data  // always 64 bytes
```

#### Examples

```kotlin
// Kotlin
val hasher = BLAKE2bp.Hasher()
hasher.update(chunk1).update(chunk2)
val digest = hasher.finalize()
```

```swift
// Swift
var hasher = BLAKE2bp.Hasher()
hasher.update(chunk1)
hasher.update(chunk2)
let digest = hasher.finalize()
```

> **Note:** BLAKE2bp produces different output than BLAKE2b for the same input. Use BLAKE2bp when you need the parallel tree structure; use BLAKE2b for standard RFC 7693 compatibility.

---

## BLAKE2sp

BLAKE2sp is an 8-way parallel tree mode built on BLAKE2s. It distributes input across eight BLAKE2s leaf instances in 512-byte superblocks, then merges them through a root BLAKE2s instance. Output is always 32 bytes.

### One-Shot Hash

#### Kotlin

```kotlin
BLAKE2sp.hash(
    input: ByteArray,
    key: ByteArray = ByteArray(0)  // 0–32 bytes
): ByteArray  // always 32 bytes
```

#### Swift

```swift
BLAKE2sp.hash(
    _ input: Data,
    key: Data = Data()               // 0–32 bytes
) -> Data  // always 32 bytes
```

#### Parameters

| Parameter | Type | Default | Constraints | Description |
|-----------|------|---------|-------------|-------------|
| `input` | byte array | — | any length | Data to hash |
| `key` | byte array | empty | 0–32 bytes | Enables keyed mode when non-empty |

#### Examples

```kotlin
// Kotlin
val hash = BLAKE2sp.hash(largeData)
val mac = BLAKE2sp.hash(largeData, key = secretKey)
```

```swift
// Swift
let hash = BLAKE2sp.hash(largeData)
let mac = BLAKE2sp.hash(largeData, key: secretKey)
```

### Streaming Hasher

#### Kotlin

```kotlin
BLAKE2sp.Hasher(key: ByteArray = ByteArray(0))
    .update(input: ByteArray): Hasher
    .finalize(): ByteArray  // always 32 bytes
```

#### Swift

```swift
var hasher = BLAKE2sp.Hasher(key: Data = Data())
hasher.update(_ input: Data)
hasher.finalize() -> Data  // always 32 bytes
```

#### Examples

```kotlin
// Kotlin
val hasher = BLAKE2sp.Hasher(key = secretKey)
hasher.update(data)
val mac = hasher.finalize()
```

```swift
// Swift
var hasher = BLAKE2sp.Hasher(key: secretKey)
hasher.update(data)
let mac = hasher.finalize()
```

> **Note:** BLAKE2sp produces different output than BLAKE2s for the same input. It is designed for parallel hashing on 32-bit platforms.

---

## BLAKE3

BLAKE3 is a modern cryptographic hash function with three built-in modes: hash, keyed hash (MAC/PRF), and key derivation (KDF). It supports extendable output (XOF) for arbitrary-length digests.

### One-Shot Functions

#### `hash` — Unkeyed Hash

```kotlin
// Kotlin
BLAKE3.hash(input: ByteArray): ByteArray  // 32 bytes
```

```swift
// Swift
BLAKE3.hash(_ input: Data) -> Data  // 32 bytes
```

Returns a 32-byte digest. For variable-length output, use the streaming `Hasher` with `finalizeXof()`.

#### `keyedHash` — MAC / PRF

```kotlin
// Kotlin
BLAKE3.keyedHash(
    key: ByteArray,   // exactly 32 bytes
    input: ByteArray
): ByteArray  // 32 bytes
```

```swift
// Swift
BLAKE3.keyedHash(
    key: Data,        // exactly 32 bytes
    data: Data
) -> Data  // 32 bytes
```

> **Key must be exactly 32 bytes.** This mode produces a keyed hash suitable for use as a message authentication code (MAC) or pseudorandom function (PRF).

#### `deriveKey` — Key Derivation

```kotlin
// Kotlin
BLAKE3.deriveKey(
    context: String,           // globally unique, hardcoded context string
    keyMaterial: ByteArray     // input key material
): ByteArray  // 32 bytes
```

```swift
// Swift
BLAKE3.deriveKey(
    context: String,           // globally unique, hardcoded context string
    keyMaterial: Data           // input key material
) -> Data  // 32 bytes
```

The `context` string should be a hardcoded, globally unique string that describes the application and purpose (e.g., `"myapp 2025-01-01 session-token"`). Never reuse a context string for different purposes.

#### One-Shot Examples

```kotlin
// Kotlin
val digest = BLAKE3.hash("Hello, world!".toByteArray())

val mac = BLAKE3.keyedHash(
    key = key32bytes,
    input = "message".toByteArray()
)

val derived = BLAKE3.deriveKey(
    context = "myapp 2025-01-01 session-token",
    keyMaterial = masterSecret
)
```

```swift
// Swift
let digest = BLAKE3.hash(Data("Hello, world!".utf8))

let mac = BLAKE3.keyedHash(
    key: key32bytes,
    data: Data("message".utf8)
)

let derived = BLAKE3.deriveKey(
    context: "myapp 2025-01-01 session-token",
    keyMaterial: masterSecret
)
```

### Streaming Hasher

The streaming `Hasher` supports all three modes and extendable output.

#### Construction

```kotlin
// Kotlin — hash mode (unkeyed)
val hasher = BLAKE3.Hasher()

// Kotlin — keyed hash mode
val keyedHasher = BLAKE3.Hasher(key = key32bytes)

// Kotlin — key derivation mode
val kdfHasher = BLAKE3.Hasher.deriveKey(context = "myapp 2025-01-01 session-token")
```

```swift
// Swift — hash mode (unkeyed)
var hasher = BLAKE3.Hasher()

// Swift — keyed hash mode
var keyedHasher = BLAKE3.Hasher(key: key32bytes)

// Swift — key derivation mode
var kdfHasher = BLAKE3.Hasher.deriveKey(context: "myapp 2025-01-01 session-token")
```

#### Updating

```kotlin
// Kotlin
hasher.update(input: ByteArray): Hasher
hasher.update(input: ByteArray, offset: Int, length: Int): Hasher
```

```swift
// Swift
hasher.update(_ input: Data)
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
hasher.finalize() -> Data

// Swift — arbitrary-length output (XOF)
hasher.finalizeXof(outputLength: Int) -> Data
```

#### Streaming Examples

```kotlin
// Kotlin — hash a file in chunks
val hasher = BLAKE3.Hasher()
inputStream.buffered().use { stream ->
    val buf = ByteArray(8192)
    var n: Int
    while (stream.read(buf).also { n = it } != -1) {
        hasher.update(buf, 0, n)
    }
}
val fileHash = hasher.finalize()

// Kotlin — XOF: generate 128 bytes of output
val xof = BLAKE3.Hasher()
    .apply { update("seed".toByteArray()) }
    .finalizeXof(128)

// Kotlin — streaming key derivation
val kdf = BLAKE3.Hasher.deriveKey("myapp 2025-01-01 encryption-key")
kdf.update(userPassword.toByteArray())
kdf.update(serverSalt)
val derivedKey = kdf.finalize()
```

```swift
// Swift — hash data in chunks
var hasher = BLAKE3.Hasher()
for chunk in dataChunks {
    hasher.update(chunk)
}
let fileHash = hasher.finalize()

// Swift — XOF: generate 128 bytes of output
var xofHasher = BLAKE3.Hasher()
xofHasher.update(Data("seed".utf8))
let xof = xofHasher.finalizeXof(outputLength: 128)

// Swift — streaming key derivation
var kdf = BLAKE3.Hasher.deriveKey(context: "myapp 2025-01-01 encryption-key")
kdf.update(Data(userPassword.utf8))
kdf.update(serverSalt)
let derivedKey = kdf.finalize()
```

### XOF (Extendable Output Function)

BLAKE3's `finalizeXof()` produces output of any requested length. The first 32 bytes of `finalizeXof(n)` are identical to `finalize()` — XOF simply extends the output beyond 32 bytes.

```kotlin
// Kotlin — the first 32 bytes match
val a = BLAKE3.Hasher().apply { update(data) }.finalize()            // 32 bytes
val b = BLAKE3.Hasher().apply { update(data) }.finalizeXof(32)       // 32 bytes
// a == b

val long = BLAKE3.Hasher().apply { update(data) }.finalizeXof(1024)  // 1024 bytes
// long[0..31] == a
```

```swift
// Swift — the first 32 bytes match
var h1 = BLAKE3.Hasher(); h1.update(data)
var h2 = BLAKE3.Hasher(); h2.update(data)
let a = h1.finalize()              // 32 bytes
let b = h2.finalizeXof(outputLength: 32)  // 32 bytes
// a == b
```

Use cases for XOF:
- Generating multiple keys from one seed
- Producing stream cipher keystreams
- Domain-separated key expansion
