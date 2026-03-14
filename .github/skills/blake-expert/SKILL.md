---
name: blake-expert
description: "BLAKE2 and BLAKE3 cryptographic hash function expert — algorithm selection, implementation, performance tuning, and security analysis. ALWAYS use this skill when the user mentions: BLAKE2, BLAKE2b, BLAKE2s, BLAKE2bp, BLAKE2sp, BLAKE2x, BLAKE3, b2sum, b3sum, blake3::hash, blake3::Hasher, blake3_hasher, keyed_hash, derive_key, BLAKE3 KDF, BLAKE3 MAC, BLAKE3 XOF, or RFC 7693. Also use when comparing hash functions for performance (BLAKE vs SHA-2, SHA-3, MD5), choosing a fast cryptographic hash for content-addressable storage, file integrity, deduplication, Merkle trees, or streaming verification, implementing keyed hashing or key derivation without HMAC, or selecting a hash for protocols like WireGuard, Argon2, Noise, or content-addressed systems like IPFS, ZFS, or git."
---

# BLAKE2 and BLAKE3 Expert

Help users understand, select, implement, and optimize the BLAKE2 and BLAKE3 cryptographic hash families. Give direct, practical guidance rooted in the specifications (RFC 7693 for BLAKE2; the BLAKE3 paper and C2SP spec for BLAKE3). Explain tradeoffs so the user can make informed decisions rather than blindly following defaults.

## Start by understanding the user's situation

BLAKE questions span several layers. Identify which one is driving the task:

- **Algorithm selection** — choosing between BLAKE2b, BLAKE2s, BLAKE2bp, BLAKE2sp, BLAKE3, or a non-BLAKE alternative
- **Mode selection** — plain hashing, keyed hashing (MAC/PRF), key derivation (KDF), or extendable output (XOF)
- **Implementation** — writing code using a BLAKE2/BLAKE3 library or implementing from primitives
- **Performance** — tuning for throughput, choosing SIMD paths, leveraging parallelism
- **Security analysis** — understanding security margins, comparing with SHA-2/SHA-3, evaluating fitness for a protocol
- **Integration** — using BLAKE in a larger system (Argon2, WireGuard, Noise, content-addressed storage, digital signatures)
- **Migration** — moving from MD5, SHA-1, SHA-2, or BLAKE2 to BLAKE3

If the question is unclear, ask about:
- The platform and CPU architecture (x86-64, ARM/NEON, 32-bit embedded, WASM)
- Whether parallelism (SIMD, multithreading) is available and desired
- The typical input size (small messages vs. large files vs. streaming)
- The language and ecosystem (Rust, C, Go, Python, Java, Swift, Kotlin, etc.)
- Whether they need a MAC, KDF, or XOF in addition to plain hashing
- The threat model and required security level

## Working style

- **Lead with the recommendation**, then explain the reasoning, then show code.
- **Show comparison tables** when choosing between variants or alternatives. Side-by-side tables with columns for word size, output size, speed, and use case are easier to scan than prose.
- **Include common pitfalls** for the topic at hand — incorrect endianness, forgetting to set the key length in the parameter block, misusing BLAKE3's `derive_key` context strings, or confusing BLAKE2b with BLAKE2bp output.
- **Provide code examples** in the user's language when possible. Favor the idiomatic library API (e.g., `blake3` crate in Rust, `hashlib` in Python, libsodium's `crypto_generichash`).
- **Cite the spec** when precision matters — refer to RFC 7693 sections for BLAKE2 and the C2SP spec sections for BLAKE3.
- Separate algorithm-level guidance from library-specific guidance. The BLAKE3 algorithm is the same everywhere; the API differs.

## Algorithm selection guide

### The BLAKE family at a glance

| Algorithm | Word size | Default output | Rounds | Key feature | Spec |
|-----------|-----------|----------------|--------|-------------|------|
| **BLAKE2b** | 64-bit | 1–64 bytes | 12 | Fast on 64-bit CPUs | RFC 7693 |
| **BLAKE2s** | 32-bit | 1–32 bytes | 10 | Fast on 32-bit/embedded | RFC 7693 |
| **BLAKE2bp** | 64-bit | 1–64 bytes | 12 | 4-way parallel BLAKE2b | BLAKE2 paper |
| **BLAKE2sp** | 32-bit | 1–32 bytes | 10 | 8-way parallel BLAKE2s | BLAKE2 paper |
| **BLAKE2x** | varies | arbitrary length | varies | XOF built on BLAKE2 | BLAKE2x paper |
| **BLAKE3** | 32-bit | 1–2⁶⁴ bytes | 7 | Merkle tree, inherently parallel, one algorithm | C2SP spec / BLAKE3 paper |

### Quick decision tree

**"Should I use BLAKE2 or BLAKE3?"**
- **BLAKE3** is the default recommendation for new projects. It is faster than BLAKE2 (especially on large inputs or with SIMD/multithreading), simpler (one algorithm, no variants to choose), and equally secure.
- **BLAKE2** is the right choice when: you need compliance with RFC 7693, your platform has a mature BLAKE2 library but no BLAKE3 support, you need 64-byte output (BLAKE2b) vs BLAKE3's 32-byte default security level, or you're working with a protocol that mandates BLAKE2 (WireGuard uses BLAKE2s, Argon2 uses BLAKE2b internally).

**"Which BLAKE2 variant?"**
- **64-bit platform (x86-64, ARM64)?** → BLAKE2b
- **32-bit or smaller (ARM Cortex-M, 8-bit MCU)?** → BLAKE2s
- **Need to hash large data with SIMD?** → BLAKE2bp (64-bit) or BLAKE2sp (32-bit)
- **Need arbitrary-length output?** → BLAKE2x (or just use BLAKE3)

**"Which BLAKE3 mode?"**
- **General-purpose hashing** → `hash` (default, no key)
- **MAC or PRF** → `keyed_hash` (takes a 32-byte key)
- **Key derivation** → `derive_key` (takes a context string + key material)
- **XOF / DRBG** → any mode with extended output (call `finalize_xof` or request more than 32 bytes)

### BLAKE3 vs SHA-2, SHA-3, and others

| Property | BLAKE3 | SHA-256 | SHA-3-256 | SHA-512 |
|----------|--------|---------|-----------|---------|
| Speed (single core, long msg) | ~4× SHA-256 | baseline | ~0.5× | ~1.5× on 64-bit |
| Parallelizable | Yes (Merkle tree) | No | No | No |
| Built-in MAC | Yes (`keyed_hash`) | No (use HMAC) | No (use KMAC) | No (use HMAC) |
| Built-in KDF | Yes (`derive_key`) | No (use HKDF) | No | No (use HKDF) |
| XOF | Yes | No | SHAKE yes | No |
| Length extension resistance | Yes | No | Yes | No |
| Output size | 32 bytes default | 32 bytes | 32 bytes | 64 bytes |
| Security level | 128 bits | 128 bits | 128 bits | 256 bits |
| Standardization | C2SP | NIST FIPS 180-4 | NIST FIPS 202 | NIST FIPS 180-4 |

**When to prefer SHA-2/SHA-3 over BLAKE3:**
- Regulatory compliance requires NIST-approved algorithms (FIPS 140-2/3)
- Interoperability with systems that only support SHA-2 (TLS certificates, X.509, JWT, most PKI)
- Need 256-bit security level (use SHA-512 or SHA-3-512; BLAKE3 targets 128-bit security)

## BLAKE2 deep dive

### How BLAKE2 works

BLAKE2 is based on the ChaCha stream cipher's quarter-round function. The core is a compression function `F` that processes message blocks:

1. **Initialize** the state `h[0..7]` from the IV, XORed with the parameter block (which encodes hash length, key length, etc.)
2. **If keyed**, the key (padded to one block) becomes the first data block
3. **Process** each block with the compression function F, which uses 12 rounds (BLAKE2b) or 10 rounds (BLAKE2s) of the G mixing function
4. **Finalize** the last block with the finalization flag set, and truncate the state to the requested output length

Key implementation details:
- The compression function mixes state `h[0..7]`, IV `[0..7]`, a counter `t`, and a finalization flag `f` into a 16-word working vector
- The G function uses 4 rotation constants: (32, 24, 16, 63) for BLAKE2b and (16, 12, 8, 7) for BLAKE2s
- Message words are permuted each round according to the SIGMA schedule (10 fixed permutations, reused cyclically)
- Little-endian byte order throughout

For the complete compression function pseudocode, G function, SIGMA schedule, and parameter block layout, see `references/blake2-specification.md`.

### BLAKE2 keyed hashing

BLAKE2 has built-in keyed hashing — no HMAC wrapper needed:
- Set the key length `kk` in the parameter block
- Pad the key to one full block and prepend it to the message
- The rest of processing is identical

This is functionally a PRF/MAC. The security proof is in the BLAKE2 paper. Advantages over HMAC-BLAKE2: single pass (HMAC does two), simpler implementation, and the keying is part of the design rather than bolted on.

### BLAKE2 tree hashing

BLAKE2's parameter block includes tree hashing parameters (fanout, depth, leaf length, node offset, node depth, inner length). This allows Merkle tree constructions for parallel hashing. BLAKE2bp and BLAKE2sp are specific instantiations:
- **BLAKE2bp**: 4 parallel BLAKE2b instances, 64-byte inner digests, then a final BLAKE2b pass over the concatenated outputs
- **BLAKE2sp**: 8 parallel BLAKE2s instances, 32-byte inner digests, then a final BLAKE2s pass

**Important**: BLAKE2bp produces different output from BLAKE2b for the same input. They are different algorithms. Same for BLAKE2sp vs BLAKE2s.

## BLAKE3 deep dive

### How BLAKE3 works

BLAKE3 uses a Merkle tree structure built on a compression function derived from BLAKE2s (but with only 7 rounds instead of 10, and a fixed permutation instead of SIGMA):

1. **Split** input into 1024-byte chunks
2. **Process each chunk** by iterating the compression function over 16 consecutive 64-byte blocks (using the chunk counter, `CHUNK_START`/`CHUNK_END` flags)
3. **Build a binary tree** — each parent node hashes the concatenation of its two children's 32-byte outputs
4. **The root node** determines the output (the `ROOT` flag triggers output extraction)

Key architectural differences from BLAKE2:
- **Merkle tree is mandatory** — even single-chunk inputs are processed through the tree logic (the chunk is just the root)
- **7 rounds** instead of 10/12 — BLAKE3 trades rounds for tree-level mixing, maintaining security through the tree structure
- **32-bit words only** — no 64-bit variant. Speed comes from parallelism, not wider words
- **Fixed permutation** — BLAKE3 uses a single message word permutation applied each round (not the SIGMA schedule)
- **Counter per chunk, not per block** — the counter `t` counts chunks, not bytes. Within a chunk, it stays constant across blocks
- **Flags for domain separation** — `CHUNK_START`, `CHUNK_END`, `PARENT`, `ROOT`, `KEYED_HASH`, `DERIVE_KEY_CONTEXT`, `DERIVE_KEY_MATERIAL`

For the complete compression function, tree construction rules (including incomplete trees), and flag definitions, see `references/blake3-specification.md`.

### BLAKE3 modes

**Hash mode** (`hash`):
- Key = IV (the SHA-256 IV)
- Input is the message
- Default 32-byte output; extend for XOF

**Keyed hash mode** (`keyed_hash`):
- Key = caller-provided 32-byte key (split into 8 little-endian words)
- Input is the message
- Sets `KEYED_HASH` flag on all compressions
- Use as MAC/PRF

**Key derivation mode** (`derive_key`):
- Phase 1: key = IV, message = context string, flag = `DERIVE_KEY_CONTEXT`
- Phase 2: key = truncated output of phase 1, message = key material, flag = `DERIVE_KEY_MATERIAL`
- The context string must be **hardcoded, globally unique, and application-specific** — never include dynamic data like salts or nonces
- Good format: `"[application] [commit timestamp] [purpose]"`, e.g., `"myapp 2024-01-15 session tokens v1"`

**Extendable output (XOF)**:
- Any mode can produce arbitrary-length output by repeating the root compression with incrementing counter `t`
- Each repetition yields 64 bytes; concatenate and truncate
- Shorter outputs are prefixes of longer ones — BLAKE3 does not domain-separate by output length
- You can seek to any position in the output stream without computing preceding bytes

### BLAKE3 parallelism

BLAKE3's Merkle tree enables parallelism at multiple levels:

1. **SIMD within the compression function** — the 4 column G calls are independent, as are the 4 diagonal G calls. Map to 128-bit SIMD (SSE2/NEON) for 4-way parallelism
2. **SIMD across chunks** — process 4/8/16 chunks simultaneously with AVX2/AVX-512
3. **Multithreading across subtrees** — different threads process different subtrees of the Merkle tree

The reference implementation is single-threaded and processes chunks sequentially. Optimized implementations (Rust `blake3` crate, C implementation) use runtime CPU feature detection to select the best SIMD path and support multithreading (via Rayon in Rust, oneTBB in C).

**Rule of thumb for multithreading** (x86-64): multithreaded `update` is slower than single-threaded for inputs under ~128 KiB. Benchmark your specific use case.

## Security considerations

### Security margins

- **BLAKE2b**: 12 rounds. Best known attack reaches 2.5 rounds. Security margin: ~4.8×
- **BLAKE2s**: 10 rounds. Best known attack reaches 2.5 rounds. Security margin: ~4×
- **BLAKE3**: 7 rounds. Security argument relies on both the compression function's rounds AND the Merkle tree structure

The core algorithm descends from ChaCha (via BLAKE), which has been extensively analyzed since 2008 as a SHA-3 finalist. NIST's SHA-3 final report noted BLAKE has a "very large security margin."

### Security levels

| Algorithm | Collision resistance | Preimage resistance | Notes |
|-----------|---------------------|--------------------|-|
| BLAKE2b-256 | 128 bits | 256 bits | |
| BLAKE2b-512 | 256 bits | 512 bits | Highest security in the family |
| BLAKE2s-256 | 128 bits | 256 bits | |
| BLAKE3 (32 bytes) | 128 bits | 128 bits | Longer output doesn't increase security beyond 128 bits |

**Key point**: BLAKE3 targets 128-bit security regardless of output length. If you need 256-bit collision resistance, use BLAKE2b-512 or SHA-512.

### What BLAKE is NOT for

- **Password hashing** — BLAKE2 and BLAKE3 are designed to be fast. Password hashing must be slow and memory-hard. Use Argon2 (which uses BLAKE2b internally), bcrypt, or scrypt.
- **If FIPS compliance is required** — BLAKE is not NIST-approved. Use SHA-2 or SHA-3.

### Length extension attacks

Both BLAKE2 and BLAKE3 are resistant to length extension attacks (unlike SHA-256 and SHA-512). This means `H(secret || message)` is a safe MAC construction, though using the built-in keyed modes is still preferred.

## Helping with test vectors and verification

When a user is implementing BLAKE2 or BLAKE3 (or verifying an existing implementation), proactively offer test vectors. Read `references/test-vectors.md` and provide the relevant vectors for their specific algorithm, mode, and output size. Don't dump the entire file — pick the ones that match.

A good verification workflow to suggest:
1. Start with empty input — catches initialization errors
2. Test "abc" — catches basic input processing bugs
3. Test boundary cases (e.g., BLAKE3 at exactly 64 bytes and 1024 bytes) — catches off-by-one errors at block/chunk boundaries
4. Test keyed mode — catches key handling bugs
5. Compare against the cross-algorithm table in the test vectors reference to make sure the right algorithm is being called

The test vectors file also includes the input generation pattern for sequential test inputs and code snippets in multiple languages to reproduce them.

## Common pitfalls

1. **Confusing BLAKE2b output with BLAKE2bp output** — these are different algorithms producing different hashes for the same input. BLAKE2bp uses 4-way parallel processing and a tree structure.

2. **Using BLAKE3 `derive_key` with dynamic context strings** — the context string must be a hardcoded constant. Put salts, nonces, and user IDs in the key material, not the context.

3. **Expecting BLAKE3 extended output to increase security** — output beyond 32 bytes provides convenience (e.g., generating multiple subkeys) but does not increase the 128-bit security level.

4. **Endianness errors in BLAKE2 parameter block** — the parameter block is little-endian. `p[0] = 0x0101kknn` where `nn` is hash length and `kk` is key length. Getting this wrong produces valid-looking but incorrect hashes.

5. **Forgetting the key block in BLAKE2 keyed hashing** — when using a key, the key must be padded to a full block and prepended to the message. The total byte count passed to the compression function includes this extra block.

6. **Assuming BLAKE3 multithreading is always faster** — for small inputs (<128 KiB on x86-64), single-threaded is faster due to thread coordination overhead.

7. **Not verifying with test vectors** — always validate your implementation against known test vectors. See `references/test-vectors.md` for comprehensive verified vectors covering all BLAKE2 and BLAKE3 variants and modes.

8. **Relying on secrecy of BLAKE3 XOF offset** — an attacker who knows the message and key can determine the output offset. Don't treat the `seek` position as secret.

## Library and API quick reference

### Rust

```rust
// BLAKE3 - the blake3 crate
let hash = blake3::hash(b"input");                           // hash mode
let mac = blake3::keyed_hash(&key, b"input");                // keyed_hash mode
let derived = blake3::derive_key("context string", material); // derive_key mode

// Incremental
let mut hasher = blake3::Hasher::new();
hasher.update(b"part1");
hasher.update(b"part2");
let hash = hasher.finalize();

// XOF
let mut xof_output = [0u8; 1000];
hasher.finalize_xof().fill(&mut xof_output);
```

### C (BLAKE3)

```c
blake3_hasher hasher;
blake3_hasher_init(&hasher);              // hash mode
// blake3_hasher_init_keyed(&hasher, key); // keyed_hash mode
// blake3_hasher_init_derive_key(&hasher, "context"); // derive_key mode

blake3_hasher_update(&hasher, input, input_len);

uint8_t output[BLAKE3_OUT_LEN];           // BLAKE3_OUT_LEN = 32
blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);
// blake3_hasher_finalize_seek(&hasher, seek_pos, output, len); // XOF with seek
```

### Python

```python
import hashlib

# BLAKE2b
h = hashlib.blake2b(b"input", digest_size=32)
h.hexdigest()

# BLAKE2b keyed
h = hashlib.blake2b(b"input", key=b"secret key up to 64 bytes", digest_size=32)

# BLAKE2s
h = hashlib.blake2s(b"input", digest_size=32)

# BLAKE3 (pip install blake3)
import blake3
blake3.blake3(b"input").hexdigest()
blake3.blake3(b"input", key=key_bytes).hexdigest()  # keyed
blake3.blake3(b"input", derive_key_context="myapp context").hexdigest()  # KDF
```

### Go

```go
// BLAKE2b — golang.org/x/crypto/blake2b
h, _ := blake2b.New256(nil)  // unkeyed, 256-bit output
h.Write(input)
sum := h.Sum(nil)

// BLAKE2b keyed
h, _ := blake2b.New256(key)

// BLAKE3 — github.com/zeebo/blake3
h := blake3.New()
h.Write(input)
sum := h.Sum(nil)
```

### Command-line

```bash
# BLAKE2 — b2sum
b2sum file.txt              # BLAKE2b-512
b2sum -a blake2s file.txt   # BLAKE2s-256
echo -n "hello" | b2sum

# BLAKE3 — b3sum
b3sum file.txt              # BLAKE3, 256-bit
b3sum --length 64 file.txt  # Extended output (64 bytes)
b3sum --keyed file.txt      # Keyed mode (reads key from stdin)
b3sum --derive-key "context" file.txt  # Key derivation
```

For full specification details, see `references/blake2-specification.md` and `references/blake3-specification.md`. For implementation patterns, platform-specific notes, embedded guidance, and CI/CD optimization, see `references/implementation-guide.md`. For verified test vectors covering all algorithms, modes, and output sizes, see `references/test-vectors.md`. For migrating from SHA-2, MD5, or BLAKE2 to BLAKE3, see `references/migration-guide.md`. For understanding why WireGuard, Argon2, Noise, and other protocols chose specific BLAKE variants, see `references/protocol-integrations.md`.
