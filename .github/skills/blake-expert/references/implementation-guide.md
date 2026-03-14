# BLAKE Implementation Guide

Platform-specific notes, library APIs, building instructions, and integration patterns.

## Language & Library Matrix

| Language | BLAKE2 Library | BLAKE3 Library |
|----------|---------------|----------------|
| **Rust** | `blake2` crate | `blake3` crate (official) |
| **C** | Reference impl (github.com/BLAKE2/BLAKE2) | Official C impl (github.com/BLAKE3-team/BLAKE3/c) |
| **Python** | `hashlib.blake2b`, `hashlib.blake2s` (stdlib) | `blake3` (pip install blake3) |
| **Go** | `golang.org/x/crypto/blake2b`, `blake2s` | `github.com/zeebo/blake3` |
| **Java** | Bouncy Castle `Blake2bDigest`, `Blake2sDigest` | Apache Commons Codec `Blake3` |
| **C#/.NET** | `NSec.Cryptography`, Bouncy Castle | `Blake3.NET` |
| **JavaScript** | `blakejs` (npm) | `blake3` (npm, via Wasm/native) |
| **Swift** | CryptoKit does not include BLAKE; use `swift-crypto` or libsodium bindings | No official; use C library via bridging |
| **Kotlin** | Bouncy Castle | Apache Commons Codec |

## Rust Implementation

### BLAKE3 (the `blake3` crate)

```toml
# Cargo.toml
[dependencies]
blake3 = "1"
# For multithreading:
# blake3 = { version = "1", features = ["rayon"] }
```

```rust
use blake3;

// Hash mode
let hash = blake3::hash(b"hello world");
println!("{}", hash); // hex string

// Incremental hashing
let mut hasher = blake3::Hasher::new();
hasher.update(b"hello ");
hasher.update(b"world");
let hash = hasher.finalize();

// Keyed hash (MAC/PRF)
let key = [0u8; 32]; // your 32-byte key
let mac = blake3::keyed_hash(&key, b"message");

// Incremental keyed hash
let mut hasher = blake3::Hasher::new_keyed(&key);
hasher.update(b"message");
let mac = hasher.finalize();

// Key derivation
let context = "myapp 2024-01-15 session tokens v1";
let derived_key = blake3::derive_key(context, b"input key material");

// Incremental key derivation
let mut hasher = blake3::Hasher::new_derive_key(context);
hasher.update(b"input key material");
let derived_key = hasher.finalize();

// XOF (extendable output)
let mut hasher = blake3::Hasher::new();
hasher.update(b"data");
let mut output = [0u8; 128]; // any length
let mut reader = hasher.finalize_xof();
reader.fill(&mut output);

// Multithreaded (requires "rayon" feature)
let mut hasher = blake3::Hasher::new();
hasher.update_rayon(large_data);
let hash = hasher.finalize();
```

The `blake3` crate automatically detects CPU features at runtime (SSE2, SSE4.1, AVX2, AVX-512, NEON) and uses the fastest available implementation.

### BLAKE2 (the `blake2` crate)

```toml
[dependencies]
blake2 = "0.10"
```

```rust
use blake2::{Blake2b512, Blake2s256, Digest};

// BLAKE2b-512
let mut hasher = Blake2b512::new();
hasher.update(b"hello world");
let hash = hasher.finalize();

// BLAKE2s-256
let mut hasher = Blake2s256::new();
hasher.update(b"hello world");
let hash = hasher.finalize();

// Variable-length output
use blake2::Blake2bVar;
use blake2::digest::VariableOutput;
let mut hasher = Blake2bVar::new(20).unwrap(); // 20-byte output
hasher.update(b"hello");
let mut buf = [0u8; 20];
hasher.finalize_variable(&mut buf).unwrap();

// Keyed BLAKE2b (MAC)
use blake2::digest::KeyInit;
let mut hasher = blake2::Blake2bMac512::new_from_slice(b"my secret key").unwrap();
hasher.update(b"message");
let mac = hasher.finalize();
```

## C Implementation

### BLAKE3

The official C implementation lives at github.com/BLAKE3-team/BLAKE3/c. It includes:
- Portable C implementation
- x86 assembly (SSE2, SSE4.1, AVX2, AVX-512) for Unix and Windows
- x86 C intrinsics versions
- ARM NEON support
- Runtime CPU feature detection on x86
- Optional multithreading via oneTBB

**API:**

```c
#include "blake3.h"

// Hash mode
blake3_hasher hasher;
blake3_hasher_init(&hasher);
blake3_hasher_update(&hasher, input, input_len);
uint8_t output[BLAKE3_OUT_LEN]; // BLAKE3_OUT_LEN = 32
blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);

// Keyed hash (MAC)
uint8_t key[BLAKE3_KEY_LEN]; // BLAKE3_KEY_LEN = 32
blake3_hasher_init_keyed(&hasher, key);
blake3_hasher_update(&hasher, input, input_len);
blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);

// Key derivation
blake3_hasher_init_derive_key(&hasher, "context string");
blake3_hasher_update(&hasher, key_material, material_len);
blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);

// XOF with seek
blake3_hasher_finalize_seek(&hasher, seek_position, output, output_len);

// Reset for reuse
blake3_hasher_reset(&hasher);

// Multithreaded update (requires oneTBB)
blake3_hasher_update_tbb(&hasher, input, input_len);
```

**Building on x86-64 Unix (with assembly):**
```bash
gcc -O3 -o example example.c blake3.c blake3_dispatch.c blake3_portable.c \
    blake3_sse2_x86-64_unix.S blake3_sse41_x86-64_unix.S \
    blake3_avx2_x86-64_unix.S blake3_avx512_x86-64_unix.S
```

**Building on x86-64 with C intrinsics:**
```bash
gcc -c -fPIC -O3 -msse2 blake3_sse2.c -o blake3_sse2.o
gcc -c -fPIC -O3 -msse4.1 blake3_sse41.c -o blake3_sse41.o
gcc -c -fPIC -O3 -mavx2 blake3_avx2.c -o blake3_avx2.o
gcc -c -fPIC -O3 -mavx512f -mavx512vl blake3_avx512.c -o blake3_avx512.o
gcc -shared -O3 -o libblake3.so blake3.c blake3_dispatch.c blake3_portable.c \
    blake3_sse2.o blake3_sse41.o blake3_avx2.o blake3_avx512.o
```

**Building portable only (no SIMD):**
```bash
gcc -O3 -DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 -DBLAKE3_NO_AVX2 \
    -DBLAKE3_NO_AVX512 blake3.c blake3_dispatch.c blake3_portable.c
```

**Building on ARM with NEON:**
```bash
gcc -shared -O3 -DBLAKE3_USE_NEON=1 blake3.c blake3_dispatch.c \
    blake3_portable.c blake3_neon.c
```

**Building with CMake:**
```bash
cmake -S c -B c/build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build c/build --target install
# With multithreading:
cmake -S c -B c/build -DBLAKE3_USE_TBB=1 -DBLAKE3_FETCH_TBB=1
```

**Note**: `sizeof(blake3_hasher)` is ~1912 bytes on x86-64. Stack-allocate is fine but be aware of the size.

### BLAKE2 (Reference C implementation)

From RFC 7693 appendices and github.com/BLAKE2/BLAKE2:

```c
#include "blake2.h"

// BLAKE2b
uint8_t hash[64];
blake2b(hash, 64, input, input_len, NULL, 0); // unkeyed, 64-byte output
blake2b(hash, 32, input, input_len, key, key_len); // keyed, 32-byte output

// BLAKE2s
uint8_t hash[32];
blake2s(hash, 32, input, input_len, NULL, 0);

// Incremental API
blake2b_state state;
blake2b_init(&state, 64);        // unkeyed
blake2b_init_key(&state, 64, key, key_len); // keyed
blake2b_update(&state, input, input_len);
blake2b_final(&state, hash, 64);
```

## Python Implementation

```python
import hashlib

# BLAKE2b (stdlib, Python 3.6+)
h = hashlib.blake2b(digest_size=32)  # 32-byte output (default is 64)
h.update(b"hello world")
print(h.hexdigest())

# One-shot
hashlib.blake2b(b"hello world", digest_size=32).hexdigest()

# Keyed BLAKE2b
h = hashlib.blake2b(key=b"secret", digest_size=32)
h.update(b"message")
mac = h.hexdigest()

# BLAKE2s
hashlib.blake2s(b"data", digest_size=32).hexdigest()

# With salt and personalization
h = hashlib.blake2b(
    b"data",
    digest_size=32,
    key=b"key",
    salt=b"saltsalt12345678",   # up to 16 bytes for BLAKE2b
    person=b"MyApp___v1.0____"  # up to 16 bytes for BLAKE2b
)

# BLAKE3 (pip install blake3)
import blake3

# Hash
blake3.blake3(b"hello world").hexdigest()

# Incremental
h = blake3.blake3()
h.update(b"hello ")
h.update(b"world")
h.hexdigest()

# Keyed hash
blake3.blake3(b"message", key=bytes(32)).hexdigest()

# Key derivation
blake3.blake3(b"key material", derive_key_context="myapp context").hexdigest()

# XOF
h = blake3.blake3(b"data")
h.digest(length=64)  # 64-byte output
```

## Go Implementation

```go
import (
    "golang.org/x/crypto/blake2b"
    "golang.org/x/crypto/blake2s"
    "github.com/zeebo/blake3"
)

// BLAKE2b-256 unkeyed
h, _ := blake2b.New256(nil)
h.Write([]byte("hello world"))
sum := h.Sum(nil) // 32-byte hash

// BLAKE2b-256 keyed
h, _ := blake2b.New256([]byte("secret key"))
h.Write([]byte("message"))
mac := h.Sum(nil)

// BLAKE2b with custom output size
h, _ := blake2b.New(48, nil) // 48-byte output
h.Write([]byte("data"))
sum := h.Sum(nil)

// BLAKE2s-256
h, _ := blake2s.New256(nil)
h.Write([]byte("data"))
sum := h.Sum(nil)

// BLAKE3
h3 := blake3.New()
h3.Write([]byte("hello world"))
sum := h3.Sum(nil)

// BLAKE3 with derive key (use the library-specific API)
// Check the zeebo/blake3 docs for keyed and derive_key modes
```

## Java / Kotlin

```java
// BLAKE2 via Bouncy Castle
import org.bouncycastle.crypto.digests.Blake2bDigest;
import org.bouncycastle.crypto.digests.Blake2sDigest;

// BLAKE2b-256
Blake2bDigest digest = new Blake2bDigest(256);
digest.update(input, 0, input.length);
byte[] hash = new byte[32];
digest.doFinal(hash, 0);

// BLAKE2b keyed
Blake2bDigest macDigest = new Blake2bDigest(key, 32, null, null);
macDigest.update(input, 0, input.length);
macDigest.doFinal(hash, 0);

// BLAKE3 via Apache Commons Codec
import org.apache.commons.codec.digest.Blake3;

byte[] hash = Blake3.hash(input);

// Incremental
Blake3 blake3 = Blake3.initHash();
blake3.update(input);
byte[] hash = new byte[32];
blake3.doFinalize(hash, 0, 32);
```

## Command-Line Tools

### b2sum

```bash
# BLAKE2b-512 (default)
b2sum file.txt
echo -n "hello" | b2sum

# BLAKE2s-256
b2sum -a blake2s file.txt

# Custom length (in bits)
b2sum -l 256 file.txt   # BLAKE2b-256

# Verify checksums
b2sum file1.txt file2.txt > checksums.txt
b2sum -c checksums.txt
```

### b3sum

```bash
# Install
cargo install b3sum

# BLAKE3 hash (default 256-bit)
b3sum file.txt
echo -n "hello" | b3sum

# Extended output
b3sum --length 64 file.txt   # 64-byte output

# Keyed mode (reads 32-byte key from stdin)
echo -n "key" | b3sum --keyed file.txt

# Key derivation
b3sum --derive-key "context string" file.txt

# Verify
b3sum file1.txt file2.txt > checksums.b3
b3sum --check checksums.b3

# b3sum uses multithreading by default — much faster than sha256sum on multicore
```

## Integration Patterns

### Content-Addressable Storage

BLAKE3 is ideal for content-addressable storage (CAS) systems:
- Fast hashing enables real-time deduplication
- Merkle tree structure matches CAS tree verification
- XOF can generate storage keys of any required length

```rust
// Content address with BLAKE3
fn content_address(data: &[u8]) -> blake3::Hash {
    blake3::hash(data)
}
```

### Incremental File Verification

BLAKE3's Merkle tree enables verified streaming — verify chunks of a file before the entire file is received:

```rust
// Using the bao crate for verified streaming
// https://github.com/oconnor663/bao
```

### Key Derivation in Protocols

Replace HKDF with BLAKE3 `derive_key`:

```rust
// Instead of HKDF-SHA256:
// let prk = hkdf_extract(salt, ikm);
// let okm = hkdf_expand(prk, info, len);

// Use BLAKE3 derive_key:
let mut hasher = blake3::Hasher::new_derive_key("myprotocol 2024-01-15 session key");
hasher.update(ikm);
let mut okm = [0u8; 32];
hasher.finalize_xof().fill(&mut okm);
```

### MAC for Message Authentication

Replace HMAC-SHA256 with BLAKE3 keyed_hash:

```rust
// Instead of HMAC-SHA256:
// let mac = hmac_sha256(key, message);

// Use BLAKE3 keyed_hash (single pass, built-in):
let mac = blake3::keyed_hash(&key, message);
```

## Performance Tuning Tips

1. **Use the official/optimized implementations** — don't use reference implementations in production. The Rust `blake3` crate and the C implementation include SIMD optimizations.

2. **Enable AVX-512 when available** — can double throughput vs AVX2 for BLAKE3.

3. **Use multithreading for large inputs** — BLAKE3's Merkle tree is designed for it. In Rust, enable the `rayon` feature. In C, build with oneTBB.

4. **Memory-map large files** — for multithreaded hashing, mmap avoids the sequential read bottleneck. Single-threaded sequential read + hash is often fine though.

5. **Benchmark your specific input sizes** — BLAKE3 multithreading has overhead; for inputs <128 KiB (on x86-64), single-threaded is faster.

6. **For many small inputs** — BLAKE3's advantage over BLAKE2 is smaller on short messages. For very small inputs (<64 bytes), the setup cost dominates.

7. **Reuse hashers** — call `blake3_hasher_reset()` (C) or create a new `Hasher` (Rust, which is essentially free) rather than re-initializing from scratch.

## Verifying SIMD / CPU Feature Usage

After building BLAKE3, verify that the expected SIMD path is actually being used:

### Check CPU features at runtime

```bash
# Linux
grep -o 'sse2\|sse4_1\|avx2\|avx512f\|avx512vl' /proc/cpuinfo | sort -u

# macOS
sysctl -a | grep -i avx

# Programmatic (C)
# blake3_dispatch.c auto-detects at runtime via CPUID
# To verify: set BLAKE3_TESTING_FORCE_PORTABLE=1 and compare speed
```

### Verify the correct build

```bash
# Check that SIMD symbols are present in the compiled binary
nm libblake3.so | grep -i avx512  # Should list blake3_compress_xof_avx512 etc.
nm libblake3.so | grep -i avx2    # Should list blake3_compress_in_place_avx2 etc.

# Rust: the blake3 crate detects features at runtime (no build flags needed)
# To verify, benchmark with/without:
BLAKE3_TESTING_FORCE_PORTABLE=1 cargo bench  # Portable only
cargo bench                                   # Auto-detect (should be faster)
```

### Troubleshooting slow BLAKE3

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| No speedup over SHA-256 | Built portable only | Rebuild with SIMD assembly/intrinsics |
| AVX2 available but not used | Missing build flags | Include `blake3_avx2_x86-64_unix.S` or `-mavx2` intrinsics |
| AVX-512 available but not faster than AVX2 | Thermal throttling | Check CPU frequency under load; some CPUs downclock with AVX-512 |
| Multithreaded slower than single-threaded | Input too small (<128 KiB) | Use single-threaded for small inputs |
| Slower on ARM than expected | NEON not enabled | Build with `-DBLAKE3_USE_NEON=1` and include `blake3_neon.c` |

## Embedded and Constrained Platforms

### Platform selection guide

| Platform | Recommended | Word size | ROM (approx) | RAM (approx) | Notes |
|----------|-------------|-----------|--------------|--------------|-------|
| x86-64 server | BLAKE3 | 32-bit (SIMD compensates) | N/A | ~2 KiB state | Use AVX2/AVX-512; enable multithreading for large inputs |
| ARM64 (Apple Silicon, server ARM) | BLAKE3 | 32-bit (NEON compensates) | N/A | ~2 KiB state | NEON acceleration built into blake3 crate |
| ARM Cortex-M4 (32-bit, 64+ KB SRAM) | BLAKE2s | 32-bit native | ~10 KiB | ~500 bytes | Fits comfortably; proven in Linux kernel RNG |
| ARM Cortex-M0/M0+ (32-bit, ≤32 KB SRAM) | BLAKE2s | 32-bit native | ~8 KiB | ~400 bytes | Use BLAKE2s-128 output if space is very tight |
| RISC-V (32-bit) | BLAKE2s | 32-bit native | ~8 KiB | ~400 bytes | Same code as Cortex-M |
| 8-bit AVR (ATmega) | BLAKE2s ref | 32-bit emulated | ~6 KiB | ~300 bytes | Slow but works; consider truncated output |
| WebAssembly | BLAKE3 or BLAKE2s | 32-bit | N/A | ~2 KiB | BLAKE3 via wasm-pack; BLAKE2s via blakejs |

### BLAKE3 state size

The `blake3_hasher` struct is approximately **1,912 bytes** on x86-64. This is mostly the chunk stack for the Merkle tree. On embedded systems with limited stack space:
- Heap-allocate the hasher if stack is constrained
- BLAKE2s state is only ~200 bytes — much more stack-friendly

### WebAssembly considerations

BLAKE3 in WebAssembly:
- **Rust → Wasm**: Compile the `blake3` crate with `wasm-pack`. No SIMD by default (Wasm SIMD proposal is supported in major browsers but not yet universal).
- **Performance**: Expect ~1/5 to 1/10 of native speed without SIMD. With Wasm SIMD (where available), closer to 1/3 of native.
- **JavaScript alternative**: The `blake3` npm package uses native bindings (fast) with a Wasm fallback. The `blakejs` npm package provides BLAKE2b/BLAKE2s in pure JS.
- **Build**:
  ```bash
  # Rust to Wasm
  wasm-pack build --target web
  
  # With Wasm SIMD (experimental)
  RUSTFLAGS="-C target-feature=+simd128" wasm-pack build --target web
  ```

### Building for embedded (bare metal)

```bash
# Cortex-M4 with BLAKE2s (using reference C implementation)
arm-none-eabi-gcc -O2 -mcpu=cortex-m4 -mthumb \
    -DBLAKE2S_SELFTEST blake2s-ref.c -o blake2s_test

# Cortex-M4 with BLAKE3 (portable only, no SIMD)
arm-none-eabi-gcc -O2 -mcpu=cortex-m4 -mthumb \
    -DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 -DBLAKE3_NO_AVX2 \
    -DBLAKE3_NO_AVX512 -DBLAKE3_NO_NEON \
    blake3.c blake3_dispatch.c blake3_portable.c -o blake3_embedded
```

## CI/CD Usage with b3sum

### Hashing large build artifacts

```bash
# Single large file (b3sum auto-uses multithreading)
b3sum build_artifacts.tar.gz > checksums.b3
# 10 GB file: ~1-2s with AVX-512, ~3-5s with AVX2

# Many files in parallel
find build/ -type f | xargs -P 8 b3sum > checksums.b3

# Recursive directory
b3sum build/**/*.o > checksums.b3

# Verify later
b3sum --check checksums.b3
```

### Performance expectations

| File size | AVX-512 (single file) | AVX2 (single file) | Notes |
|-----------|----------------------|---------------------|-------|
| 1 MB | <10 ms | <20 ms | I/O dominates |
| 100 MB | ~15 ms | ~30 ms | Hashing becomes visible |
| 1 GB | ~150 ms | ~300 ms | BLAKE3 multithreading helps |
| 10 GB | ~1.5 s | ~3 s | I/O may become bottleneck |

### Tips for CI pipelines

1. **Cache checksums**: Store `checksums.b3` as a build artifact. On the next build, `b3sum --check` is faster than re-hashing if most files haven't changed.
2. **Parallel file hashing**: For many small files, `xargs -P N` is more effective than relying on b3sum's internal multithreading (which parallelizes within a single file).
3. **I/O bottleneck**: If hashing is slower than expected, the bottleneck is likely disk I/O, not CPU. Use `iostat` or `iotop` to diagnose.
4. **Install b3sum**: `cargo install b3sum` or use pre-built binaries from the BLAKE3 GitHub releases.
