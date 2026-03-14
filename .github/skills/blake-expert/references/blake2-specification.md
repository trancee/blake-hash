# BLAKE2 Specification Reference

Condensed from RFC 7693, the BLAKE2 paper (blake2.pdf), and the BLAKE2x paper (blake2x.pdf).

## Overview

BLAKE2 is a cryptographic hash function faster than MD5, SHA-1, SHA-2, and SHA-3, while providing at least the security level of SHA-3. BLAKE2 was designed by Jean-Philippe Aumasson, Samuel Neves, Zooko Wilcox-O'Hearn, and Christian Winnerlein. It is specified in RFC 7693 and licensed under CC0 (public domain).

BLAKE2 is based on the SHA-3 finalist BLAKE, which itself uses the core algorithm of the ChaCha stream cipher by Daniel J. Bernstein.

## Variants

### BLAKE2b
- Optimized for **64-bit** platforms (including NEON-enabled ARM)
- Word size: 64 bits
- Block size: 128 bytes
- Rounds: 12
- Output: 1 to 64 bytes
- Key: 0 to 64 bytes
- Max input: 2^128 bytes
- Rotation constants (R1, R2, R3, R4): (32, 24, 16, 63)

### BLAKE2s
- Optimized for **8- to 32-bit** platforms
- Word size: 32 bits
- Block size: 64 bytes
- Rounds: 10
- Output: 1 to 32 bytes
- Key: 0 to 32 bytes
- Max input: 2^64 bytes
- Rotation constants (R1, R2, R3, R4): (16, 12, 8, 7)

### BLAKE2bp (4-way parallel BLAKE2b)
- 4 parallel BLAKE2b instances
- Each processes every 4th block
- Final hash: BLAKE2b of concatenated inner digests
- Different output from BLAKE2b for the same input

### BLAKE2sp (8-way parallel BLAKE2s)
- 8 parallel BLAKE2s instances
- Each processes every 8th block
- Final hash: BLAKE2s of concatenated inner digests
- Different output from BLAKE2s for the same input

### BLAKE2x (extendable output)
- Built on BLAKE2b or BLAKE2s as inner hash
- Produces arbitrary-length output (up to 256 GiB)
- Uses the inner hash's output as input to multiple BLAKE2 calls with different node offsets

## Initialization Vector (IV)

Derived from the fractional parts of the square roots of the first 8 primes:

```
IV[i] = floor(2^w * frac(sqrt(prime(i+1))))
```

BLAKE2b IV (same as SHA-512 IV):
```
IV[0] = 0x6a09e667f3bcc908
IV[1] = 0xbb67ae8584caa73b
IV[2] = 0x3c6ef372fe94f82b
IV[3] = 0xa54ff53a5f1d36f1
IV[4] = 0x510e527fade682d1
IV[5] = 0x9b05688c2b3e6c1f
IV[6] = 0x1f83d9abfb41bd6b
IV[7] = 0x5be0cd19137e2179
```

BLAKE2s IV (same as SHA-256 IV):
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

## Parameter Block

The parameter block encodes configuration. For the basic (non-tree) case:

```
Byte offset:   3  2  1  0
      p[0] = 0x0101kknn
      p[1..7] = 0
```

Where:
- `nn` = hash output length in bytes
- `kk` = key length in bytes (0 for unkeyed)
- Bytes 2 and 3 are set to 01 01

Full parameter block (all features, 8 words / 64 bytes for BLAKE2b):

| Offset | Length | Name | Description |
|--------|--------|------|-------------|
| 0 | 1 | Digest length | 1..64 for BLAKE2b, 1..32 for BLAKE2s |
| 1 | 1 | Key length | 0..64 for BLAKE2b, 0..32 for BLAKE2s |
| 2 | 1 | Fanout | 0..255 (0 = unlimited, 1 = sequential) |
| 3 | 1 | Depth | 1..255 (1 = sequential) |
| 4 | 4 | Leaf length | 0..2^32-1 (0 = unlimited) |
| 8 | 8/6 | Node offset | For tree hashing |
| 16/14 | 1 | Node depth | Current node depth |
| 17/15 | 1 | Inner length | Inner hash digest length |
| 18/16 | 14/8 | Reserved | Must be zero |
| 32/24 | 16/8 | Salt | Optional salt |
| 48/32 | 16/8 | Personalization | Optional personalization string |

For simple sequential hashing: fanout=1, depth=1, leaf length=0, all tree params=0.

## Message Schedule (SIGMA)

10 fixed permutations of indices 0..15, used cyclically across rounds:

```
SIGMA[0]  =  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
SIGMA[1]  = 14 10  4  8  9 15 13  6  1 12  0  2 11  7  5  3
SIGMA[2]  = 11  8 12  0  5  2 15 13 10 14  3  6  7  1  9  4
SIGMA[3]  =  7  9  3  1 13 12 11 14  2  6  5 10  4  0 15  8
SIGMA[4]  =  9  0  5  7  2  4 10 15 14  1 11 12  6  8  3 13
SIGMA[5]  =  2 12  6 10  0 11  8  3  4 13  7  5 15 14  1  9
SIGMA[6]  = 12  5  1 15 14 13  4 10  0  7  6  3  9  2  8 11
SIGMA[7]  = 13 11  7 14 12  1  3  9  5  0 15  4  8  6  2 10
SIGMA[8]  =  6 15 14  9 11  3  0  8 12  2 13  7  1  4 10  5
SIGMA[9]  = 10  2  8  4  7  6  1  5 15 11  9 14  3 12 13  0
```

BLAKE2b uses rounds 0..11 with SIGMA[i mod 10]. BLAKE2s uses rounds 0..9.

## Mixing Function G

The G primitive mixes two message words `x` and `y` into four words at positions `a`, `b`, `c`, `d` in the 16-word working vector:

```
FUNCTION G(v[0..15], a, b, c, d, x, y)
    v[a] := (v[a] + v[b] + x) mod 2^w
    v[d] := (v[d] ^ v[a]) >>> R1
    v[c] := (v[c] + v[d])     mod 2^w
    v[b] := (v[b] ^ v[c]) >>> R2
    v[a] := (v[a] + v[b] + y) mod 2^w
    v[d] := (v[d] ^ v[a]) >>> R3
    v[c] := (v[c] + v[d])     mod 2^w
    v[b] := (v[b] ^ v[c]) >>> R4
    RETURN v[0..15]
END FUNCTION
```

## Compression Function F

```
FUNCTION F(h[0..7], m[0..15], t, f)
    // Initialize local work vector v[0..15]
    v[0..7]  := h[0..7]           // First half from state
    v[8..15] := IV[0..7]          // Second half from IV

    v[12] := v[12] ^ (t mod 2^w)  // Low word of offset counter
    v[13] := v[13] ^ (t >> w)     // High word of offset counter

    IF f = TRUE THEN               // Last block flag
        v[14] := v[14] ^ 0xFF..FF  // Invert all bits
    END IF

    // Cryptographic mixing
    FOR i = 0 TO r-1 DO           // 12 rounds (BLAKE2b) or 10 (BLAKE2s)
        s[0..15] := SIGMA[i mod 10][0..15]

        v := G(v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]])
        v := G(v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]])
        v := G(v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]])
        v := G(v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]])

        v := G(v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]])
        v := G(v, 1, 6, 11, 12, m[s[10]], m[s[11]])
        v := G(v, 2, 7,  8, 13, m[s[12]], m[s[13]])
        v := G(v, 3, 4,  9, 14, m[s[14]], m[s[15]])
    END FOR

    FOR i = 0 TO 7 DO
        h[i] := h[i] ^ v[i] ^ v[i + 8]
    END FOR

    RETURN h[0..7]
END FUNCTION
```

## Overall Hash Computation

```
FUNCTION BLAKE2(d[0..dd-1], ll, kk, nn)
    h[0..7] := IV[0..7]
    h[0] := h[0] ^ 0x01010000 ^ (kk << 8) ^ nn

    // Process padded key and data blocks
    IF dd > 1 THEN
        FOR i = 0 TO dd-2 DO
            h := F(h, d[i], (i + 1) * bb, FALSE)
        END FOR
    END IF

    // Final block
    IF kk = 0 THEN
        h := F(h, d[dd-1], ll, TRUE)
    ELSE
        h := F(h, d[dd-1], ll + bb, TRUE)
    END IF

    RETURN first nn bytes from little-endian word array h[]
END FUNCTION
```

Where:
- `d[0..dd-1]` = padded message blocks (each `bb` bytes)
- `ll` = message length in bytes (not including key block)
- `kk` = key length in bytes
- `nn` = desired hash length in bytes
- `dd` = ceil(kk/bb) + ceil(ll/bb) (or 1 if both are 0)
- `bb` = block size (128 for BLAKE2b, 64 for BLAKE2s)

If keyed (kk > 0): pad key to bb bytes → d[0]; data fills d[1..dd-1].
If unkeyed and empty: dd = 1, d[0] = all zeros.

## Standard Algorithm Identifiers

| Algorithm | OID | Output bytes |
|-----------|-----|------|
| BLAKE2b-160 | 1.3.6.1.4.1.1722.12.2.1.5 | 20 |
| BLAKE2b-256 | 1.3.6.1.4.1.1722.12.2.1.8 | 32 |
| BLAKE2b-384 | 1.3.6.1.4.1.1722.12.2.1.12 | 48 |
| BLAKE2b-512 | 1.3.6.1.4.1.1722.12.2.1.16 | 64 |
| BLAKE2s-128 | 1.3.6.1.4.1.1722.12.2.2.4 | 16 |
| BLAKE2s-160 | 1.3.6.1.4.1.1722.12.2.2.5 | 20 |
| BLAKE2s-224 | 1.3.6.1.4.1.1722.12.2.2.7 | 28 |
| BLAKE2s-256 | 1.3.6.1.4.1.1722.12.2.2.8 | 32 |

## Notable Users of BLAKE2

- **Linux kernel RNG**: BLAKE2s as entropy extractor
- **WireGuard**: BLAKE2s for hashing and MAC
- **Argon2**: BLAKE2b as internal hash (PHC winner, password hashing)
- **Noise Protocol Framework**: BLAKE2s and BLAKE2b as hash options
- **libsodium**: BLAKE2b as default hash (`crypto_generichash`)
- **OpenSSL**: includes BLAKE2b and BLAKE2s
- **WinRAR**: BLAKE2sp as optional checksum in RAR 5.0
- **Bouncy Castle**: BLAKE2b-160/256/384/512

## Test Vectors

See `test-vectors.md` for comprehensive verified test vectors for BLAKE2b and BLAKE2s, including unkeyed, keyed, various output sizes, single-byte inputs, and sequential inputs.

Quick reference — BLAKE2b-512 and BLAKE2s-256, empty input (useful as a sanity check):

```
BLAKE2b-512("") = 786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419
                  d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce

BLAKE2s-256("") = 69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9
```

## Cryptanalysis Summary

Best known attacks (as of the BLAKE2 paper and subsequent research):
- The best attack on reduced BLAKE2 works on **2.5 rounds**
- BLAKE2b has 12 rounds → security margin of ~4.8×
- BLAKE2s has 10 rounds → security margin of ~4×
- At 2.5 rounds, BLAKE2b preimage security drops from 512 to 481 bits; BLAKE2s collision security drops from 128 to 112 bits
- No practical attack exists on full-round BLAKE2

Key papers:
- Guo, Karpman, Nikolić, Wang, Wu (2013): "Analysis of BLAKE2" — most comprehensive analysis
- Hao (2014): "Boomerang Attacks on BLAKE and BLAKE2"
- Espitau, Fouque, Karpman (2015): Higher-order differential meet-in-the-middle preimage attacks
