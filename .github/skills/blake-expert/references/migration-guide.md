# Migration Guide: Moving to BLAKE3

How to migrate from SHA-2, MD5, BLAKE2, or other hash functions to BLAKE3, with practical checklists, API mapping tables, and gotcha warnings.

## Table of Contents

- [Should you migrate?](#should-you-migrate)
- [SHA-256 → BLAKE3](#sha-256--blake3)
- [SHA-512 → BLAKE3 or BLAKE2b](#sha-512--blake3-or-blake2b)
- [MD5 / SHA-1 → BLAKE3](#md5--sha-1--blake3)
- [BLAKE2 → BLAKE3](#blake2--blake3)
- [HMAC-SHA-256 → BLAKE3 keyed_hash](#hmac-sha-256--blake3-keyed_hash)
- [HKDF → BLAKE3 derive_key](#hkdf--blake3-derive_key)
- [Dual-hash transition strategy](#dual-hash-transition-strategy)
- [Common migration pitfalls](#common-migration-pitfalls)

---

## Should you migrate?

**Migrate to BLAKE3 when:**
- Performance matters (BLAKE3 is 3–5× faster than SHA-256 single-threaded, much more with SIMD/multithreading)
- You need a built-in MAC, KDF, or XOF without external constructions
- You want verified streaming (Merkle tree) for large files
- Your system is not constrained by compliance requirements

**Stay on SHA-2 when:**
- FIPS 140-2/3 compliance is required (BLAKE3 is not NIST-approved)
- You need interoperability with systems that only support SHA-2 (TLS certificates, X.509, JWT, PKI)
- The hash function is not a performance bottleneck

**Stay on BLAKE2 when:**
- Your protocol mandates it (WireGuard requires BLAKE2s, Argon2 uses BLAKE2b internally)
- You need RFC 7693 compliance
- You need 256-bit collision resistance (use BLAKE2b-512; BLAKE3 targets 128-bit)
- Existing code is working well and throughput is acceptable

---

## SHA-256 → BLAKE3

The most common migration path. Output sizes are compatible (both default to 32 bytes).

### Output compatibility

| Property | SHA-256 | BLAKE3 | Compatible? |
|----------|---------|--------|-------------|
| Default output | 32 bytes | 32 bytes | ✅ Yes |
| Security level | 128-bit collision | 128-bit collision | ✅ Same |
| Length extension | Vulnerable | Resistant | ✅ BLAKE3 better |
| Byte order | Big-endian internally, hex output | Little-endian internally, hex output | ✅ Hex strings match format |

### API mapping

**Python:**
```python
# Before (SHA-256)
import hashlib
h = hashlib.sha256(data).hexdigest()

# After (BLAKE3)
import blake3
h = blake3.blake3(data).hexdigest()
```

**Rust:**
```rust
// Before (SHA-256, using sha2 crate)
use sha2::{Sha256, Digest};
let hash = Sha256::digest(data);

// After (BLAKE3)
let hash = blake3::hash(data);
```

**Go:**
```go
// Before (SHA-256)
import "crypto/sha256"
h := sha256.Sum256(data)

// After (BLAKE3)
import "github.com/zeebo/blake3"
h := blake3.Sum256(data)
```

**C:**
```c
// Before (OpenSSL SHA-256)
SHA256(input, input_len, output);

// After (BLAKE3)
blake3_hasher hasher;
blake3_hasher_init(&hasher);
blake3_hasher_update(&hasher, input, input_len);
blake3_hasher_finalize(&hasher, output, 32);
```

**Command line:**
```bash
# Before
sha256sum file.txt

# After
b3sum file.txt
```

### Verification during switchover

Hash the same input with both algorithms to verify your BLAKE3 setup produces correct output:

```python
import hashlib, blake3

data = b"migration test"

sha = hashlib.sha256(data).hexdigest()
b3  = blake3.blake3(data).hexdigest()

assert sha == "d7e09acbbfd2e1b64213522f72f73e0c0c3f07b40aa5e5e5076f29c47c1fee14"
assert b3  == "0a0ee29ad01a0e0f1fcae6ab2a6ed41a4e0c07fa6ac0ded91a98cbf9b7d1c075"
```

---

## SHA-512 → BLAKE3 or BLAKE2b

SHA-512 produces 64 bytes with 256-bit collision resistance. BLAKE3 defaults to 32 bytes with 128-bit collision resistance. Choose your replacement based on your security requirements:

| Need | Replacement | Rationale |
|------|-------------|-----------|
| Just hashing, 128-bit security is fine | BLAKE3 (32 bytes) | Faster, simpler |
| Need 64-byte output but 128-bit security is fine | BLAKE3 XOF (64 bytes) | Use `finalize_xof` or `digest(length=64)` |
| Need 256-bit collision resistance | BLAKE2b-512 | Only option in the BLAKE family |

**Important**: BLAKE3's extended output (XOF) does **not** increase the security level beyond 128 bits. If you specifically chose SHA-512 for 256-bit collision resistance (e.g., for Ed25519 signature schemes), use BLAKE2b-512 instead of BLAKE3.

---

## MD5 / SHA-1 → BLAKE3

MD5 and SHA-1 are cryptographically broken. If you're still using them, migrate immediately — not just for performance but for security.

| Property | MD5 | SHA-1 | BLAKE3 |
|----------|-----|-------|--------|
| Output size | 16 bytes | 20 bytes | 32 bytes (default) |
| Collision resistance | Broken | Broken | 128 bits |
| Speed (approximate) | ~5 bytes/cycle | ~3 bytes/cycle | ~7 bytes/cycle |

### Output size change

MD5 (16 bytes) and SHA-1 (20 bytes) produce shorter outputs than BLAKE3 (32 bytes). You may need to update:
- Database column widths (32→64 hex chars for MD5, 40→64 for SHA-1)
- Fixed-size buffer allocations
- String comparison logic
- URL-encoded hash parameters

### Dual-output period

If your system stores MD5/SHA-1 hashes (e.g., for file deduplication), you'll need to rehash existing data during the transition. See [dual-hash transition strategy](#dual-hash-transition-strategy) below.

---

## BLAKE2 → BLAKE3

### Why migrate from BLAKE2?

- **Performance**: BLAKE3 is 2–5× faster than BLAKE2 with SIMD, even more with multithreading
- **Simplicity**: One algorithm (no BLAKE2b vs. BLAKE2s vs. BLAKE2bp vs. BLAKE2sp decisions)
- **Built-in modes**: `keyed_hash` and `derive_key` replace BLAKE2's keyed mode and custom KDF constructions
- **XOF**: Arbitrary-length output without needing BLAKE2x
- **Verified streaming**: Merkle tree structure enables incremental verification

### What changes

| BLAKE2 feature | BLAKE3 equivalent | Notes |
|----------------|-------------------|-------|
| BLAKE2b (64-bit) | BLAKE3 | BLAKE3 uses 32-bit words but compensates with parallelism |
| BLAKE2s (32-bit) | BLAKE3 | BLAKE3 is derived from BLAKE2s |
| BLAKE2b keyed | `keyed_hash` | Key must be exactly 32 bytes (BLAKE2b allows up to 64) |
| BLAKE2s keyed | `keyed_hash` | Key must be exactly 32 bytes (BLAKE2s allows up to 32) |
| BLAKE2b-512 (256-bit security) | No equivalent | BLAKE3 targets 128-bit security only |
| BLAKE2bp / BLAKE2sp | BLAKE3 | BLAKE3's tree mode replaces explicit parallel variants |
| BLAKE2 salt parameter | No direct equivalent | Put salt in `derive_key` key material or prepend to message |
| BLAKE2 personalization | No direct equivalent | Use `derive_key` with a unique context string |

### Key size differences

BLAKE2b accepts keys up to 64 bytes. BLAKE2s accepts up to 32 bytes. BLAKE3's `keyed_hash` requires exactly 32 bytes. If your BLAKE2 key is longer than 32 bytes, hash it down to 32 bytes first (with BLAKE3 itself) or use `derive_key` to derive a 32-byte key from the original.

### Salt and personalization

BLAKE2 has built-in salt (16 bytes for BLAKE2b, 8 for BLAKE2s) and personalization parameters. BLAKE3 doesn't have these as separate fields. Instead:

```python
# BLAKE2b with salt and personalization
hashlib.blake2b(data, key=key, salt=salt, person=b"MyApp")

# BLAKE3 equivalent: use derive_key to incorporate salt + personalization
# The context string acts as personalization
import blake3
h = blake3.blake3(salt + data, derive_key_context="MyApp v1 data hash")
```

---

## HMAC-SHA-256 → BLAKE3 keyed_hash

HMAC-SHA-256 is the most common MAC construction. BLAKE3's `keyed_hash` is a drop-in replacement that's simpler and faster.

### Why switch

| Property | HMAC-SHA-256 | BLAKE3 keyed_hash |
|----------|-------------|-------------------|
| Passes over data | 2 (inner + outer hash) | 1 |
| Key setup | Complex (ipad/opad XOR) | Direct (key as chaining value) |
| Key size | Any (hashed if > block size) | Exactly 32 bytes |
| Output size | 32 bytes | 32 bytes (extendable) |
| Speed | ~SHA-256 speed | ~BLAKE3 speed (3–5× faster) |

### API mapping

**Python:**
```python
# Before
import hmac, hashlib
mac = hmac.new(key, data, hashlib.sha256).hexdigest()

# After
import blake3
mac = blake3.blake3(data, key=key_32bytes).hexdigest()
```

**Rust:**
```rust
// Before (using hmac + sha2 crates)
use hmac::{Hmac, Mac};
use sha2::Sha256;
let mut mac = Hmac::<Sha256>::new_from_slice(key)?;
mac.update(data);
let result = mac.finalize().into_bytes();

// After
let result = blake3::keyed_hash(&key, data);
```

### Key handling difference

HMAC accepts keys of any length (long keys are hashed, short keys are padded). BLAKE3 `keyed_hash` requires exactly 32 bytes. If your existing HMAC key is not 32 bytes:

```python
# Derive a 32-byte key from an arbitrary-length key
derived = blake3.blake3(original_key).digest()  # Always 32 bytes
mac = blake3.blake3(data, key=derived).hexdigest()
```

---

## HKDF → BLAKE3 derive_key

HKDF (RFC 5869) is a two-step KDF: extract + expand. BLAKE3's `derive_key` combines both steps and is simpler.

### Mapping HKDF concepts

| HKDF concept | BLAKE3 derive_key equivalent |
|-------------|-------------------------------|
| Salt | Not needed (BLAKE3's context string provides domain separation) |
| IKM (input key material) | Key material (the data input to `derive_key`) |
| Info | Context string (hardcoded, globally unique) |
| OKM (output key material) | Output (32 bytes default, extendable via XOF) |

### API mapping

**Python:**
```python
# Before (HKDF-SHA256)
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
kdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=salt, info=b"session key")
derived = kdf.derive(key_material)

# After (BLAKE3 derive_key)
import blake3
derived = blake3.blake3(key_material, derive_key_context="myapp 2024-01 session key").digest()
```

**Rust:**
```rust
// Before (using hkdf crate)
let hk = Hkdf::<Sha256>::new(Some(salt), ikm);
let mut okm = [0u8; 32];
hk.expand(info, &mut okm)?;

// After
let okm = blake3::derive_key("myapp 2024-01 session key", ikm);
```

### What about the salt?

HKDF uses an optional salt for extra randomness. BLAKE3's `derive_key` doesn't have a salt parameter. If your HKDF usage depends on a salt:

```python
# Include the salt in the key material
derived = blake3.blake3(
    salt + key_material,
    derive_key_context="myapp 2024-01 session key"
).digest()
```

The context string must remain hardcoded and constant — never put dynamic data (salts, nonces, timestamps) in the context string. Dynamic data goes in the key material.

---

## Dual-hash transition strategy

For systems that store hashes (checksums, content-addressed storage, dedup), you can't switch atomically. Use a transition period:

### Phase 1: Dual-write (N weeks)
- Compute and store **both** old and new hashes for all new data
- Add a `hash_algorithm` field to your storage schema

### Phase 2: Backfill
- Rehash existing data with BLAKE3 in the background
- Track progress (how many objects rehashed vs. remaining)

### Phase 3: Dual-read
- Accept lookups by either hash
- New writes only compute BLAKE3

### Phase 4: Cleanup
- Remove old hash columns/fields
- Update all clients to use BLAKE3 only

### Example schema change

```sql
-- Before
CREATE TABLE objects (
    sha256_hash CHAR(64) PRIMARY KEY,
    data BLOB
);

-- Phase 1: Add BLAKE3 column
ALTER TABLE objects ADD COLUMN blake3_hash CHAR(64);
CREATE INDEX idx_blake3 ON objects(blake3_hash);

-- Phase 4: Drop SHA-256
ALTER TABLE objects DROP COLUMN sha256_hash;
ALTER TABLE objects ADD PRIMARY KEY (blake3_hash);
```

---

## Common migration pitfalls

1. **Assuming BLAKE3 XOF provides more security than 128 bits.** Extended output is for convenience (e.g., generating multiple subkeys), not for increasing the security level. If you need 256-bit collision resistance (e.g., replacing SHA-512 in Ed25519), use BLAKE2b-512 instead.

2. **Forgetting to update hash length in schemas.** MD5 (32 hex chars) and SHA-1 (40 hex chars) produce shorter hex strings than BLAKE3 (64 hex chars). Check column widths, buffer sizes, and URL parameters.

3. **Using the wrong key size for keyed_hash.** BLAKE3 requires exactly 32 bytes. HMAC accepts any length. If you pass an arbitrary-length key to BLAKE3, you'll get an error — hash the key to 32 bytes first.

4. **Putting dynamic data in derive_key context strings.** The context string must be hardcoded. Salts, nonces, user IDs, and timestamps go in the key material.

5. **Not benchmarking after migration.** BLAKE3 is faster than SHA-256, but your bottleneck may be I/O, not hashing. Benchmark to confirm the speedup materializes in your system.

6. **Breaking backward compatibility too quickly.** Use the dual-hash transition strategy above. Existing clients need time to upgrade.

7. **Comparing hashes across algorithms.** BLAKE3("abc") ≠ SHA-256("abc"). During transition, make sure you're comparing like with like. Tag stored hashes with their algorithm.
