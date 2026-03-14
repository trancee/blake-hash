# Protocol and System Integrations

Why specific protocols chose BLAKE2/BLAKE3, how the hash is used in each system, and practical integration guidance. Use this reference when users ask about BLAKE in the context of a specific protocol or system.

## Table of Contents

- [WireGuard](#wireguard)
- [Argon2](#argon2)
- [Noise Protocol Framework](#noise-protocol-framework)
- [Content-Addressed Storage (IPFS, Git, ZFS)](#content-addressed-storage)
- [libsodium](#libsodium)
- [Linux Kernel RNG](#linux-kernel-rng)
- [Verified Streaming with BAO](#verified-streaming-with-bao)

---

## WireGuard

### What it uses

BLAKE2s-256 (not BLAKE2b, not BLAKE3).

### Where in the protocol

WireGuard uses BLAKE2s in two roles:
1. **HASH function** in the Noise IKpsk2 handshake — hashing handshake transcripts, chaining keys, and static keys
2. **MAC function** — BLAKE2s keyed mode (the built-in MAC, not HMAC) for message authentication during the handshake
3. **HMAC construction** — WireGuard constructs HMAC-BLAKE2s for the Noise key derivation (despite BLAKE2s having built-in keyed mode, the Noise spec requires HMAC)
4. **Cookie MAC** — BLAKE2s-128 (16-byte output) for under-load cookie responses

### Why BLAKE2s was chosen

Jason Donenfeld (WireGuard author) selected BLAKE2s for these reasons:
- **32-bit word size** matches ChaCha20 (also 32-bit) — both derive from Daniel Bernstein's designs, sharing rotation constants and structure. This means the same SIMD optimization strategy applies to both.
- **Speed**: BLAKE2s is faster than SHA-256 on all platforms, especially ARM without SHA extensions.
- **128-bit security suffices**: WireGuard's symmetric security level is 128 bits throughout (Curve25519, ChaCha20-Poly1305, BLAKE2s). No need for BLAKE2b's higher security margin.
- **Simplicity**: One hash function for all purposes (hash, MAC, KDF via HMAC). No separate HMAC or HKDF library needed.
- **RFC 7693**: Standardized, well-analyzed, with known test vectors.

### Why not BLAKE2b or BLAKE3?

- **BLAKE2b**: 64-bit words are unnecessary overhead on 32-bit embedded platforms. WireGuard targets everything from routers to phones.
- **BLAKE3**: Didn't exist when WireGuard was designed (WireGuard: 2017, BLAKE3: 2020). Also, BLAKE3's reduced rounds (7 vs. 10) would raise questions for a VPN protocol, and BLAKE3's parallelism benefits don't help for the short messages in a handshake.

### Integration notes

WireGuard is specified with BLAKE2s — it cannot be swapped for another hash without creating an incompatible protocol. If you're implementing WireGuard, use BLAKE2s exactly as specified.

---

## Argon2

### What it uses

BLAKE2b internally (not BLAKE2s, not BLAKE3).

### Where in the algorithm

Argon2 (the Password Hashing Competition winner) uses BLAKE2b in several places:
1. **Initial hash H** — BLAKE2b-512 hashes the concatenation of password, salt, and parameters into a 64-byte digest
2. **Variable-length hash H'** — A modified BLAKE2b that produces outputs of any requested length (for generating the initial blocks and the final tag)
3. **Block compression** — The compression function within Argon2's memory-hard core uses BLAKE2b's G function (two rounds of G applied to 1024-byte blocks)

### Why BLAKE2b was chosen

The Argon2 designers (Alex Biryukov, Daniel Dinu, Dmitry Khovratovich) chose BLAKE2b for:
- **64-bit words**: Argon2 targets x86-64 servers where password verification typically runs. BLAKE2b's 64-bit operations are native.
- **512-bit output**: Argon2 needs 64 bytes of initial state. BLAKE2b-512 provides this natively without output extension.
- **Speed**: The initial hashing step is not the bottleneck (the memory-hard loop is), but a fast initial hash minimizes constant overhead.
- **Same cryptographic family**: BLAKE2b's G function is reused directly in Argon2's block compression, reducing the total code footprint.

### Why not BLAKE3?

- Argon2 was published in 2015; BLAKE3 in 2020
- Argon2 is standardized (RFC 9106) with BLAKE2b — changing the internal hash would create an incompatible algorithm
- BLAKE3's parallelism benefits don't apply inside Argon2 (the memory-hard loop is deliberately sequential)

### Integration notes

If you're using Argon2 for password hashing, you don't interact with BLAKE2b directly — Argon2 libraries handle it internally. The main question users have is usually "should I use BLAKE3 for passwords?" The answer is **no** — use Argon2 (which uses BLAKE2b internally). BLAKE3 is fast; password hashing must be slow and memory-hard.

---

## Noise Protocol Framework

### What it uses

BLAKE2b or BLAKE2s (configurable). Noise defines a "CipherSuite" that includes a hash function, and BLAKE2 variants are first-class options.

### Standard Noise hash options

| Hash name in Noise | Algorithm | Output | Security |
|--------------------|-----------|--------|----------|
| `BLAKE2b` | BLAKE2b-512 | 64 bytes | 256-bit collision |
| `BLAKE2s` | BLAKE2s-256 | 32 bytes | 128-bit collision |
| `SHA256` | SHA-256 | 32 bytes | 128-bit collision |
| `SHA512` | SHA-512 | 64 bytes | 256-bit collision |

### Where in the protocol

Noise uses the hash function for:
1. **HASH(data)** — Direct hashing of handshake payloads
2. **HMAC-HASH(key, data)** — Despite BLAKE2 having built-in keyed mode, Noise uses the HMAC construction with BLAKE2 as the underlying hash. This is for proof-of-security compatibility with the Noise security proofs, which assume HMAC.
3. **HKDF(chaining_key, input_key_material)** — Key derivation using HMAC-HASH. Outputs 2 or 3 keys per call.

### Choosing BLAKE2s vs BLAKE2b in Noise

- **BLAKE2s** (Noise_XX_25519_ChaChaPoly_BLAKE2s): 128-bit security. Matches Curve25519 + ChaChaPoly. Used by WireGuard. Good for constrained environments.
- **BLAKE2b** (Noise_XX_25519_ChaChaPoly_BLAKE2b): 256-bit security margin. Higher safety margin. 64-byte hash output means HKDF produces more keying material per call.

**Rule of thumb**: If the rest of your cipher suite is 128-bit (Curve25519 + ChaCha20-Poly1305), use BLAKE2s — the security levels match. If you want extra margin or are using stronger primitives, use BLAKE2b.

### Why not BLAKE3 in Noise?

BLAKE3 is not currently defined as a Noise hash option in the specification. Reasons:
- Noise predates BLAKE3 (Noise: 2018, BLAKE3: 2020)
- BLAKE3's 128-bit security level means it can't replace BLAKE2b for applications needing >128-bit collision resistance
- The Noise spec requires HMAC construction, but BLAKE3's `keyed_hash` is not HMAC — a Noise implementation would need to construct HMAC-BLAKE3, negating BLAKE3's "no HMAC needed" advantage
- Community hasn't standardized a BLAKE3 variant for Noise yet

---

## Content-Addressed Storage

### IPFS

IPFS uses a "multihash" system that supports multiple hash functions. BLAKE2b-256 and BLAKE3 are both supported via multicodec identifiers:
- `0xb220` — BLAKE2b-256
- `0x1e` — BLAKE3

BLAKE3 is increasingly preferred for new IPFS implementations due to speed. The Merkle DAG structure of IPFS aligns naturally with BLAKE3's Merkle tree.

### Git

Git uses SHA-1 by default (with SHA-256 as an experimental option). BLAKE3 is not a Git hash option, but some Git-adjacent tools (build systems, caching layers) use BLAKE3 for content addressing.

### ZFS / OpenZFS

OpenZFS added BLAKE3 as a checksum option. It replaced the aging Fletcher-4 and SHA-256 options for deduplication and integrity checking:
- **Why BLAKE3**: 3–5× faster than SHA-256, parallelizable across the pool's vdevs, cryptographically secure (unlike Fletcher-4)
- **Configuration**: `zfs set checksum=blake3 pool/dataset`
- **Dedup**: BLAKE3's speed makes cryptographic dedup practical at scale

### Bazel / Build Systems

Bazel uses BLAKE3 for action cache keys and output hashing. The combination of speed + collision resistance enables deterministic builds without bottlenecking on hash computation.

---

## libsodium

### What it exposes

libsodium's `crypto_generichash` family is BLAKE2b:
- `crypto_generichash()` — BLAKE2b with configurable output length (16–64 bytes)
- `crypto_generichash_init()` / `update()` / `final()` — Incremental interface
- `crypto_generichash_keyed()` — BLAKE2b with a key (built-in MAC)

### Key details

- Default output: 32 bytes (BLAKE2b-256)
- Default key: none (unkeyed)
- `crypto_generichash_BYTES_MIN` = 16, `crypto_generichash_BYTES_MAX` = 64
- `crypto_generichash_KEYBYTES_MIN` = 16, `crypto_generichash_KEYBYTES_MAX` = 64

### For implementers

If you see `crypto_generichash` in code and need to implement it without libsodium, it's BLAKE2b with these defaults. Use the BLAKE2b reference implementation or any BLAKE2b library, making sure to match the output size and key handling.

---

## Linux Kernel RNG

### What it uses

BLAKE2s (since Linux 5.17, replacing SHA-1).

### Why BLAKE2s

- **32-bit friendly**: The kernel RNG runs on everything from embedded ARM to x86-64. BLAKE2s's 32-bit words work efficiently on all platforms.
- **Speed**: Entropy extraction happens on every syscall to `/dev/urandom` and `getrandom()`. BLAKE2s is significantly faster than SHA-1 on all tested architectures.
- **Security**: SHA-1 collision attacks made it uncomfortable to keep using, even though the RNG usage pattern (as a PRF, not for collision resistance) wasn't directly threatened.
- **Simplicity**: BLAKE2s is a single function (no HMAC wrapper needed for the PRF use case).

The kernel uses BLAKE2s as an entropy extractor — it hashes raw entropy from hardware sources (interrupts, CPU jitter, etc.) into a uniform seed for the ChaCha20-based CSPRNG.

---

## Verified Streaming with BAO

### What is BAO?

BAO (BLAKE3 Authenticated and Ordered) is a format for verified streaming of BLAKE3-hashed data. It uses BLAKE3's Merkle tree to enable:
- **Incremental verification**: Verify any chunk of a file without downloading the entire file
- **Random access**: Seek to any position and verify from there
- **Streaming**: Start using data before the full file arrives

### How it works

1. **Encoding**: Split the file into 1024-byte BLAKE3 chunks. Build the Merkle tree. Store the tree alongside (or interleaved with) the data.
2. **Slice extraction**: To serve a byte range, extract the relevant chunks plus the Merkle proof (sibling hashes from leaf to root).
3. **Verification**: The receiver checks each chunk against the proof using the root hash.

### Proof size

For a file of N chunks:
- Merkle tree height: ⌈log₂(N)⌉
- Proof per chunk: height × 32 bytes (one sibling hash per level)
- Example: 1 GiB file ≈ 1M chunks → proof ≈ 20 × 32 = 640 bytes per chunk

### Rust API (bao crate)

```rust
use bao::encode;

// Encode: compute hash and tree
let (hash, encoded) = bao::encode::encode(input);

// Decode and verify a slice
let mut decoder = bao::decode::SliceDecoder::new(
    &encoded_slice,
    &hash,
    slice_start,
    slice_len,
);
let mut output = vec![0u8; slice_len as usize];
decoder.read_exact(&mut output)?;
// If this returns Ok, the slice is verified
```

### When to use BAO vs plain BLAKE3

| Use case | Plain BLAKE3 | BAO |
|----------|-------------|-----|
| Hash a file for integrity | ✅ | Overkill |
| Verify file after full download | ✅ | Overkill |
| Verify chunks during download | ❌ | ✅ |
| Random access verification | ❌ | ✅ |
| Content delivery / CDN | ❌ | ✅ |
| P2P file sharing (verify untrusted chunks) | ❌ | ✅ |

---

## Summary: Which BLAKE variant for which protocol

| Protocol/System | Hash | Why |
|----------------|------|-----|
| WireGuard | BLAKE2s | 32-bit alignment with ChaCha20, 128-bit security suffices |
| Argon2 | BLAKE2b | 64-bit for x86-64, 512-bit output for internal state |
| Noise (128-bit suite) | BLAKE2s | Matches Curve25519 + ChaChaPoly security level |
| Noise (256-bit margin) | BLAKE2b | Higher collision resistance margin |
| libsodium generichash | BLAKE2b | Flexible output size, keyed mode built-in |
| Linux kernel RNG | BLAKE2s | 32-bit portable, fast entropy extraction |
| OpenZFS checksums | BLAKE3 | Speed + parallelism for storage workloads |
| IPFS content addressing | BLAKE2b-256 or BLAKE3 | Both supported; BLAKE3 gaining traction |
| Bazel build cache | BLAKE3 | Speed for hashing build artifacts |
| Verified streaming | BLAKE3 (BAO) | Merkle tree enables chunk verification |
