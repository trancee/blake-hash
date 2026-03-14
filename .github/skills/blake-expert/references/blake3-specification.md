# BLAKE3 Specification Reference

Condensed from the C2SP specification (c2sp.org/BLAKE3) and the BLAKE3 paper.

## Overview

BLAKE3 is a cryptographic hash function designed to be much faster than MD5, SHA-1, SHA-2, SHA-3, and BLAKE2, while maintaining strong security. It was designed by Jack O'Connor, Samuel Neves, Jean-Philippe Aumasson, and Zooko Wilcox-O'Hearn. Development was sponsored by Electric Coin Company.

BLAKE3 is based on an optimized instance of BLAKE2s (with reduced rounds) combined with a Merkle tree mode. It is specified by the C2SP (Community Cryptography Specification Project) at c2sp.org/BLAKE3 and in the BLAKE3 paper.

Key properties:
- **One algorithm** — no variants to choose between (unlike BLAKE2b/BLAKE2s/BLAKE2bp/BLAKE2sp)
- **Highly parallelizable** — Merkle tree structure enables SIMD and multithreaded processing
- **Multiple modes** — hash, keyed_hash, derive_key (all in one algorithm)
- **XOF** — extendable output of arbitrary length
- **Verified streaming** — Merkle tree enables incremental verification
- **Fast** — approximately 5× faster than BLAKE2 with AVX-512 single-threaded; 20×+ with multithreading

## Constants

### Initial Value (IV)

Same as SHA-256 IV (and BLAKE2s IV):
```
IV[0] = 0x6a09e667
IV[1] = 0xbb67ae85
IV[2] = 0x3c6ef372
IV[3] = 0xa54ff53a
IV[4] = 0x510e527f
IV[5] = 0x9b05688c
IV[6] = 0x1f83d9ab
IV[7] = 0x5be0cd19
```

### Message Word Permutation

BLAKE3 uses a single fixed permutation (not the 10-permutation SIGMA schedule of BLAKE2):

```
Original:  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
Permuted:  2,  6,  3, 10,  7,  0,  4, 13,  1, 11, 12,  5,  9, 14, 15,  8
```

Applied once per round. Pre-computed permutations for all 7 rounds:

```
Round 0:  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
Round 1:  2,  6,  3, 10,  7,  0,  4, 13,  1, 11, 12,  5,  9, 14, 15,  8
Round 2:  3,  4, 10, 12, 13,  2,  7, 14,  6,  5,  9,  0, 11, 15,  8,  1
Round 3: 10,  7, 12,  9, 14,  3, 13, 15,  4,  0, 11,  2,  5,  8,  1,  6
Round 4: 12, 13,  9, 11, 15, 10, 14,  8,  7,  2,  5,  3,  0,  1,  6,  4
Round 5:  9, 14, 11,  5,  8, 12, 15,  1, 13,  3,  0, 10,  2,  6,  4,  7
Round 6: 11, 15,  5,  0,  1,  9,  8,  6, 14, 10,  2, 12,  3,  4,  7, 13
```

### Compression Function Flags

```
CHUNK_START          = 0x01    // First block of a chunk
CHUNK_END            = 0x02    // Last block of a chunk
PARENT               = 0x04    // Parent (non-chunk) node
ROOT                 = 0x08    // Root node of the tree
KEYED_HASH           = 0x10    // keyed_hash mode
DERIVE_KEY_CONTEXT   = 0x20    // derive_key mode, phase 1 (context string)
DERIVE_KEY_MATERIAL  = 0x40    // derive_key mode, phase 2 (key material)
```

Multiple flags are combined with OR/XOR/addition. For example, a single-block single-chunk hash has flags `CHUNK_START | CHUNK_END | ROOT = 0x0B`.

## Quarter-Round Function G

Same structure as BLAKE2s G, with rotation constants (16, 12, 8, 7):

```
FUNCTION G(v[0..15], a, b, c, d, x, y)
    v[a] := (v[a] + v[b] + x) mod 2^32
    v[d] := (v[d] ^ v[a]) >>> 16
    v[c] := (v[c] + v[d])     mod 2^32
    v[b] := (v[b] ^ v[c]) >>> 12
    v[a] := (v[a] + v[b] + y) mod 2^32
    v[d] := (v[d] ^ v[a]) >>> 8
    v[c] := (v[c] + v[d])     mod 2^32
    v[b] := (v[b] ^ v[c]) >>> 7
    RETURN v[0..15]
END FUNCTION
```

## Compression Function

Takes 8-word chaining value `h`, 16-word message block `m`, 2-word counter `t`, data length `len`, and `flags`:

```
FUNCTION BLAKE3_COMPRESS(h[0..7], m[0..15], t, len, flags)
    // Initialize local 16-word array
    v[0..7]  := h[0..7]           // From state
    v[8..11] := IV[0..3]          // From IV
    v[12]    := t[0]              // Low word of counter
    v[13]    := t[1]              // High word of counter
    v[14]    := len               // Data length
    v[15]    := flags             // Flags

    // 7 rounds of mixing
    FOR i = 0 TO 6 DO
        // Column step
        v := G(v, 0, 4,  8, 12, m[ 0], m[ 1])
        v := G(v, 1, 5,  9, 13, m[ 2], m[ 3])
        v := G(v, 2, 6, 10, 14, m[ 4], m[ 5])
        v := G(v, 3, 7, 11, 15, m[ 6], m[ 7])

        // Diagonal step
        v := G(v, 0, 5, 10, 15, m[ 8], m[ 9])
        v := G(v, 1, 6, 11, 12, m[10], m[11])
        v := G(v, 2, 7,  8, 13, m[12], m[13])
        v := G(v, 3, 4,  9, 14, m[14], m[15])

        PERMUTE(m)    // Apply the fixed permutation
    END FOR

    // Output (untruncated)
    FOR i = 0 TO 7 DO
        v[i]     := v[i] ^ v[i + 8]
        v[i + 8] := v[i + 8] ^ h[i]
    END FOR

    RETURN v[0..15]
END FUNCTION
```

**Key difference from BLAKE2**: The output XOR includes `v[i+8] ^ h[i]` in addition to the standard `v[i] ^ v[i+8]`. This produces a 16-word (64-byte) output. For non-root nodes, only the first 8 words (32 bytes) are used. For the root, all 16 words may be used.

## Tree Mode of Operation

### Chunk Processing

1. Split input into **1024-byte chunks** (last chunk may be shorter; empty input = one empty chunk)
2. Split each chunk into **64-byte blocks** (last block may be shorter, padded with zeros)
3. Process each chunk by iterating the compression function over its blocks:
   - `h`: For the first block, use the 8-word key. For subsequent blocks, use the truncated (8-word) output of the previous compression
   - `m`: The current 64-byte block (parsed as 16 little-endian 32-bit words)
   - `t`: The chunk counter (0, 1, 2, ...) — same for all blocks within a chunk
   - `len`: Block length (64 for all except possibly the last block of the last chunk)
   - `flags`: `CHUNK_START` for the first block, `CHUNK_END` for the last, both if single-block chunk. `ROOT` added to the last block if this chunk is the only chunk

### The 8-word Key

The "key" used as the initial chaining value depends on the mode:

| Mode | Key |
|------|-----|
| `hash` | IV (the SHA-256 constants) |
| `keyed_hash` | Caller's 32-byte key split into 8 little-endian words |
| `derive_key` phase 1 | IV |
| `derive_key` phase 2 | Truncated output of phase 1 |

### Binary Tree Construction

After processing all chunks, build a binary Merkle tree:

1. If there is **only one chunk**, it is the root
2. Otherwise, merge chunks pairwise with parent nodes
3. Each parent node compresses the concatenation (64 bytes) of its two children's 32-byte outputs
4. Parent node compression uses: `h` = key, `m` = concatenated children, `t` = 0, `len` = 64, `flags` includes `PARENT`

**Incomplete tree rules** (when chunk count is not a power of 2):
- Left subtrees are **full** (complete binary trees, power-of-2 leaf count)
- Left subtrees are **big** (left ≥ right in leaf count)

Example with 6 chunks:
```
        ROOT
       /    \
     P        P
    / \      / \
   P   P    C4  C5
  / \ / \
 C0 C1 C2 C3
```
Left subtree has 4 chunks (power of 2), right subtree has 2.

### Parent Node Inputs

| Input | Value |
|-------|-------|
| `h[0..7]` | The 8-word key |
| `m[0..15]` | 64-byte concatenation of two children's 32-byte outputs |
| `t[0..1]` | 0 |
| `len` | 64 |
| `flags` | `PARENT` (+ `ROOT` if this is the tree root, + mode flag) |

### Extendable Output (XOF)

BLAKE3 can produce arbitrary-length output:

1. Compute the root node
2. Repeat the root compression with incrementing counter `t` = 0, 1, 2, ...
3. Each repetition yields 64 bytes (full 16-word output)
4. Concatenate and truncate to desired length

Properties:
- Shorter outputs are **prefixes** of longer ones (no domain separation by length)
- Can **seek** to any position — computing output block N doesn't require blocks 0..N-1
- The repeated root compressions are independent → parallelizable

**Security note**: Don't rely on secrecy of the output offset. An attacker knowing the message and key can determine the seek position.

## Hashing Modes

### Hash Mode

Standard unkeyed hashing:
- Key = IV
- Input = message
- No mode-specific flags (only structural flags: CHUNK_START, CHUNK_END, PARENT, ROOT)
- Default output: 32 bytes

### Keyed Hash Mode

MAC/PRF:
- Key = caller-provided 32-byte key
- Input = message
- `KEYED_HASH` flag set on ALL compressions (chunk and parent)
- Default output: 32 bytes

### Key Derivation Mode

Two-phase KDF:
- **Phase 1** (context hashing):
  - Key = IV
  - Message = context string
  - `DERIVE_KEY_CONTEXT` flag on all compressions
  - Output: truncated to first 8 words (32 bytes) → becomes key for phase 2

- **Phase 2** (key material hashing):
  - Key = phase 1 output
  - Message = key material
  - `DERIVE_KEY_MATERIAL` flag on all compressions
  - Output: the derived key

Context string requirements:
- **Hardcoded** — never generated at runtime
- **Globally unique** — across all applications
- **Application-specific** — ties the derived key to its purpose
- Good format: `"[application] [commit timestamp] [purpose]"`
- Dynamic data (salts, nonces, user IDs) goes in the key material, NOT the context

## Test Vectors

See `test-vectors.md` for comprehensive verified test vectors for BLAKE3 covering hash mode (including boundary cases at block/chunk boundaries), keyed hash mode, derive key mode, and extended output (XOF).

Quick reference — BLAKE3 hash mode, common inputs:

```
BLAKE3("")     = af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262
BLAKE3("abc")  = 6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85
BLAKE3("IETF") = 83a2de1ee6f4e6ab686889248f4ec0cf4cc5709446a682ffd1cbb4d6165181e2
```

## Performance Characteristics

Benchmarks on Cascade Lake-SP 8275CL (single thread, 16 KiB input):
- BLAKE3: ~6.7 bytes/cycle
- BLAKE2b: ~3.5 bytes/cycle
- SHA-256: ~1.8 bytes/cycle
- SHA-512: ~2.7 bytes/cycle (on 64-bit)
- SHA-3-256: ~1.0 bytes/cycle
- MD5: ~4.9 bytes/cycle

With multithreading on large inputs, BLAKE3 can achieve >20× the throughput of BLAKE2.

BLAKE3 uses 32-bit words (like BLAKE2s) but achieves high performance through:
1. Reduced rounds (7 vs 10 for BLAKE2s)
2. SIMD parallelism within and across chunks
3. Multithreaded tree processing

## Adoption

Major projects using BLAKE3:
- **Bazel**: Build system file hashing
- **Cargo**: Rust package manager
- **Ccache**: Compiler cache
- **LLVM**: Compiler infrastructure
- **Nix**: Package manager
- **OpenZFS**: Filesystem checksums
- **Solana**: Blockchain program hashing
- **IPFS**: Content addressing
- **Wasmer**: WebAssembly runtime

## Security

BLAKE3 targets **128-bit security** for all goals (collision, preimage, PRF, MAC), assuming the core compression function is safe.

The compression function uses 7 rounds of the BLAKE2s-derived G function. Security relies on:
1. The compression function's per-chunk security
2. The Merkle tree's structural security guarantees
3. Domain separation via flags

### BLAKE3 Security Argument: 7 Rounds + Merkle Tree

The reduced round count (7 vs. BLAKE2s's 10) is BLAKE3's most common security concern. The argument for why 7 rounds suffice:

**Round-level security**: Best known attacks on the BLAKE2s compression function (which uses the same G function) reach 2.5 rounds. BLAKE3's 7 rounds provide a margin of ~2.8× at the compression function level alone.

**Tree-level security**: The Merkle tree adds structural security that doesn't exist in sequential hash functions:
- Each parent node independently mixes two 32-byte children through 7 rounds of compression
- An attacker must break the compression function at the chunk level AND exploit the tree structure
- Domain separation flags (`CHUNK_START`, `CHUNK_END`, `PARENT`, `ROOT`) prevent cross-domain attacks

**Combined security**: The total security argument is stronger than either component alone — it's not "7 rounds OR tree" but "7 rounds AND tree."

### Comparison with other hash functions

| Function | Internal rounds | Structure | Security argument | Best known attack |
|----------|----------------|-----------|-------------------|-------------------|
| BLAKE3 | 7 | Merkle tree | Rounds + tree mixing | 2.5 rounds on G function |
| BLAKE2b | 12 | Sequential (Merkle-Damgård-like) | Rounds only | 2.5 rounds on G function |
| BLAKE2s | 10 | Sequential (Merkle-Damgård-like) | Rounds only | 2.5 rounds on G function |
| SHA-256 | 64 | Merkle-Damgård | Rounds only | 46 rounds (preimage) |
| SHA-3-256 | 24 | Sponge | Rounds + capacity | 8 rounds (collision) |

**BLAKE3 vs. SHA-3 security margin**: SHA-3 has 24 rounds with best attacks at 8 rounds (margin ~3×). BLAKE3 has 7 rounds with best attacks at 2.5 rounds (margin ~2.8×) plus additional tree-level security. The margins are comparable, but through different mechanisms.

**Why the designers consider 7 rounds safe**: The BLAKE3 paper argues that reducing from 10 rounds (BLAKE2s) to 7 rounds is conservative because:
1. The 2.5-round attack on BLAKE2s has not been improved since 2013
2. The ChaCha/Salsa family (same G function) has been analyzed since 2005 with no attacks above ~7 rounds on the full-width state
3. The tree structure provides an independent security layer that sequential hashes lack

BLAKE3 is NOT suitable for:
- Password hashing (too fast — use Argon2)
- Applications requiring >128-bit collision resistance (use BLAKE2b-512 or SHA-512)
- FIPS-compliant environments (not NIST-approved)
