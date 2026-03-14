# Algorithm Guide

Guidance on choosing the right BLAKE algorithm and mode for your application.

---

## Comparison Table

| | BLAKE2b | BLAKE2s | BLAKE2bp | BLAKE2sp | BLAKE3 |
|---|---------|---------|----------|----------|--------|
| **Standard** | RFC 7693 | RFC 7693 | RFC 7693 (tree) | RFC 7693 (tree) | [BLAKE3 spec](https://github.com/BLAKE3-team/BLAKE3-spec) |
| **Word size** | 64-bit | 32-bit | 64-bit | 32-bit | 32-bit |
| **Block size** | 128 B | 64 B | 128 B | 64 B | 64 B |
| **Default digest** | 64 B | 32 B | 64 B (fixed) | 32 B (fixed) | 32 B |
| **Variable digest** | 1–64 B | 1–32 B | No | No | XOF (unlimited) |
| **Max key** | 64 B | 32 B | 64 B | 32 B | 32 B (exact) |
| **Salt** | 16 B | 8 B | — | — | — |
| **Personalization** | 16 B | 8 B | — | — | — |
| **Rounds** | 12 | 10 | 12 | 10 | 7 |
| **Internal parallelism** | 1 | 1 | 4-way | 8-way | Unbounded (tree) |
| **Security (bits)** | 256 | 128 | 256 | 128 | 128 |
| **KDF mode** | — | — | — | — | ✅ |
| **XOF mode** | — | — | — | — | ✅ |

---

## When to Use Which

### BLAKE2b — The Default Choice

Use BLAKE2b when you need a **well-established, high-security hash** on 64-bit hardware (all modern phones and servers).

- ✅ Strongest security margin (256-bit collision resistance)
- ✅ RFC standardized — widest interoperability
- ✅ Variable-length output (1–64 bytes)
- ✅ Salt and personalization support
- ✅ Battle-tested in production (WireGuard, Argon2, libsodium)

Best for: general hashing, file integrity, digital signatures, Merkle trees, keyed MAC.

### BLAKE2s — For 32-Bit and Embedded Targets

Use BLAKE2s when targeting **32-bit platforms** or when you need a **32-byte digest** and want maximum compatibility.

- ✅ Faster than BLAKE2b on 32-bit hardware
- ✅ Same RFC 7693 specification
- ✅ Used as BLAKE3's compression function basis
- ⚠️ 128-bit collision resistance (sufficient for most applications)

Best for: 32-bit embedded systems, IoT, constrained environments.

### BLAKE2bp / BLAKE2sp — Parallel Tree Hashing

Use the parallel variants when hashing **large data** and you have multi-core hardware.

- ✅ BLAKE2bp: 4-way parallel BLAKE2b (64-bit)
- ✅ BLAKE2sp: 8-way parallel BLAKE2s (32-bit)
- ⚠️ Different output than BLAKE2b/BLAKE2s (not interchangeable)
- ⚠️ Fixed digest size (64 B for bp, 32 B for sp)
- ⚠️ No salt/personalization at API level

Best for: checksumming large files, disk images, database dumps.

### BLAKE3 — Modern and Versatile

Use BLAKE3 when you want a **modern, fast, all-in-one** hash function with built-in KDF and XOF.

- ✅ Fastest BLAKE variant
- ✅ Built-in keyed hash (MAC), key derivation (KDF), and XOF
- ✅ Unbounded internal parallelism (tree structure)
- ✅ Simpler API (fewer parameters)
- ⚠️ Not an RFC/NIST standard (but well-analyzed)
- ⚠️ Key must be exactly 32 bytes (no variable-length keys)

Best for: content-addressed storage, streaming verification, key derivation, any new project without interoperability constraints.

---

## Decision Flowchart

```
Need RFC/NIST compliance?
├── Yes → BLAKE2b (64-bit) or BLAKE2s (32-bit)
└── No
    ├── Need KDF or XOF? → BLAKE3
    ├── Need variable-length output > 64 bytes? → BLAKE3 (XOF)
    ├── Need salt or personalization? → BLAKE2b or BLAKE2s
    ├── Hashing large data, need speed? → BLAKE3 or BLAKE2bp/BLAKE2sp
    └── General purpose? → BLAKE3 (simplest) or BLAKE2b (most established)
```

---

## Security Levels

| Algorithm | Collision Resistance | Preimage Resistance | Length Extension |
|-----------|---------------------|---------------------|-----------------|
| BLAKE2b-512 | 256 bits | 512 bits | Immune |
| BLAKE2b-256 | 128 bits | 256 bits | Immune |
| BLAKE2s-256 | 128 bits | 256 bits | Immune |
| BLAKE2bp | 256 bits | 512 bits | Immune |
| BLAKE2sp | 128 bits | 256 bits | Immune |
| BLAKE3 | 128 bits | 256 bits | Immune |

All BLAKE variants are **immune to length-extension attacks** (unlike raw SHA-256 and SHA-512). You can safely use `BLAKE2b(key ‖ message)` without the HMAC construction, though the dedicated keyed mode is preferred.

### Security Margins

- **BLAKE2b**: 12 rounds; best known attack covers 2.5 rounds. Safety margin: ~4.8×
- **BLAKE2s**: 10 rounds; best known attack covers 2.5 rounds. Safety margin: ~4×
- **BLAKE3**: 7 rounds; reduced margin is a deliberate speed/security tradeoff. Safety margin: ~2.8×

All variants provide comfortable security margins for current and foreseeable threats.

---

## Mode Selection

### Unkeyed Hash

The default mode. Use for checksums, integrity verification, content addressing, and Merkle trees.

```kotlin
Blake2b.hash(data)
Blake3.hash(data)
```

### Keyed Hash (MAC / PRF)

Use when you need to **authenticate** data with a secret key. This replaces HMAC — no need for the HMAC construction with BLAKE.

```kotlin
// BLAKE2b: variable-length key (1–64 bytes)
Blake2b.hash(data, key = secretKey)

// BLAKE3: key must be exactly 32 bytes
Blake3.keyedHash(key32, data)
```

**When to use which keyed mode:**
- BLAKE2b keyed: when your key isn't exactly 32 bytes, or you need RFC 7693 compatibility
- BLAKE3 keyed: when you have a 32-byte key and want the simplest/fastest option

### Key Derivation (KDF)

BLAKE3 only. Derives subkeys from key material using a context string.

```kotlin
val encKey = Blake3.deriveKey("myapp 2025-01-01 encryption", masterKey)
val macKey = Blake3.deriveKey("myapp 2025-01-01 mac", masterKey)
```

**Context string rules:**
- Must be globally unique and hardcoded (never user-supplied)
- Should include: application name, date/version, purpose
- Different contexts produce independent keys from the same material

### Extendable Output (XOF)

BLAKE3 only. Produces arbitrary-length output. The first 32 bytes are identical to `finalize()`.

```kotlin
val expanded = Blake3.Hasher().apply { update(seed) }.finalizeXof(256)
```

Use cases:
- Generating multiple keys from a single seed
- Stream cipher keystream
- Domain-separated key expansion

---

## Performance Characteristics

Relative performance on modern hardware (higher is faster):

| Algorithm | 64-bit ARM/x86 | 32-bit ARM | Short Messages |
|-----------|-----------------|------------|----------------|
| BLAKE2b   | ★★★★☆ | ★★☆☆☆ | ★★★★☆ |
| BLAKE2s   | ★★★☆☆ | ★★★★☆ | ★★★★☆ |
| BLAKE2bp  | ★★★★☆ | ★★☆☆☆ | ★★☆☆☆ |
| BLAKE2sp  | ★★★☆☆ | ★★★★☆ | ★★☆☆☆ |
| BLAKE3    | ★★★★★ | ★★★★☆ | ★★★★★ |

Notes:
- BLAKE3 is the fastest due to fewer rounds (7 vs 10–12) and tree structure
- BLAKE2bp/sp have higher throughput on large inputs but more overhead on short messages
- BLAKE2b outperforms BLAKE2s on 64-bit hardware; BLAKE2s outperforms BLAKE2b on 32-bit hardware
- This library is a pure implementation — native/SIMD-optimized libraries will be faster for bulk operations

---

## Common Pitfalls

### 1. Confusing BLAKE2b and BLAKE2bp Output

BLAKE2bp produces **different output** than BLAKE2b for the same input. They are not interchangeable. The same applies to BLAKE2s vs BLAKE2sp.

### 2. BLAKE3 Key Length

BLAKE3 `keyedHash` requires a key of **exactly 32 bytes**. Passing a shorter or longer key will throw an error. If your key is a different length, use BLAKE2b keyed mode or hash your key to 32 bytes first.

### 3. Reusing Hashers After Finalize

Do not call `update()` after `finalize()`. Create a new `Hasher` instance for each hash computation.

### 4. Comparing Hashes Insecurely

When verifying MACs, use constant-time comparison to prevent timing attacks. Both Kotlin's `MessageDigest.isEqual()` and custom constant-time loops are appropriate. Do **not** use `==` on byte arrays for MAC verification in security-sensitive code.

### 5. Using Raw BLAKE for Password Hashing

BLAKE2 and BLAKE3 are **fast** hash functions. For password hashing, use a dedicated algorithm like Argon2 (which uses BLAKE2b internally), bcrypt, or scrypt. Raw BLAKE is trivially brute-forced for passwords.

---

## What BLAKE Is NOT For

| Use Case | Why Not | Use Instead |
|----------|---------|-------------|
| **Password hashing** | Too fast; vulnerable to brute force | Argon2id, bcrypt, scrypt |
| **FIPS 140 compliance** | Not NIST-approved | SHA-2, SHA-3 |
| **Post-quantum signatures** | Not a post-quantum primitive | SPHINCS+, Dilithium |
| **Encryption** | Hash functions don't encrypt | AES-GCM, ChaCha20-Poly1305 |
| **Random number generation** | Not a CSPRNG | OS-provided CSPRNG |

---

## References

- [RFC 7693 — BLAKE2](https://datatracker.ietf.org/doc/html/rfc7693)
- [BLAKE2 paper](https://blake2.net/blake2.pdf)
- [BLAKE3 specification](https://github.com/BLAKE3-team/BLAKE3-spec/blob/master/blake3.pdf)
- [BLAKE3 paper](https://github.com/BLAKE3-team/BLAKE3-spec)
