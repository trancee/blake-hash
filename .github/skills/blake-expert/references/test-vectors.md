# BLAKE2 and BLAKE3 Test Vectors

Verified test vectors for all BLAKE2 and BLAKE3 variants. Use these to validate implementations. All values are hex-encoded.

When helping a user verify their implementation, provide the relevant vectors for their specific algorithm, mode, and output size. Don't dump the entire file — pick the ones that match their use case.

## Table of Contents

- [BLAKE2b](#blake2b)
  - [Unkeyed](#blake2b-unkeyed)
  - [Sequential Inputs (BLAKE2b-512)](#sequential-inputs-at-various-sizes-blake2b-512)
  - [Sequential Inputs (BLAKE2b-256)](#sequential-inputs-at-various-sizes-blake2b-256)
  - [Keyed](#blake2b-keyed)
  - [Salt and Personalization](#blake2b-salt-and-personalization)
- [BLAKE2s](#blake2s)
  - [Unkeyed](#blake2s-unkeyed)
  - [Keyed](#blake2s-keyed)
  - [Sequential Inputs (BLAKE2s-256)](#blake2s-sequential-inputs-blake2s-256)
  - [Sequential Inputs (BLAKE2s-128)](#blake2s-128-sequential-inputs)
- [BLAKE2bp (4-way parallel BLAKE2b)](#blake2bp-4-way-parallel-blake2b)
  - [Unkeyed](#blake2bp-unkeyed)
  - [Keyed](#blake2bp-keyed)
- [BLAKE2sp (8-way parallel BLAKE2s)](#blake2sp-8-way-parallel-blake2s)
  - [Unkeyed](#blake2sp-unkeyed)
  - [Keyed](#blake2sp-keyed)
- [BLAKE3](#blake3)
  - [Hash Mode](#blake3-hash-mode)
  - [Hash Mode — Larger Sequential Inputs](#larger-sequential-inputs)
  - [Keyed Hash Mode](#blake3-keyed-hash-mode)
  - [Derive Key Mode](#blake3-derive-key-mode)
  - [Extended Output (XOF)](#blake3-extended-output-xof)
- [Cross-Algorithm Comparison](#cross-algorithm-comparison)
  - [Keyed Cross-Algorithm Comparison](#keyed-cross-algorithm-comparison)
- [Using These Vectors](#using-these-vectors)

---

## BLAKE2b

### BLAKE2b Unkeyed

#### Empty input

| Output size | Hash |
|-------------|------|
| 256 bits (32 bytes) | `0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8` |
| 384 bits (48 bytes) | `b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100` |
| 512 bits (64 bytes) | `786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce` |

#### Input: "abc" (0x616263)

| Output size | Hash |
|-------------|------|
| 256 bits (32 bytes) | `bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319` |
| 384 bits (48 bytes) | `6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4` |
| 512 bits (64 bytes) | `ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923` |

#### Input: "The quick brown fox jumps over the lazy dog"

| Output size | Hash |
|-------------|------|
| 256 bits (32 bytes) | `01718cec35cd3d796dd00020e0bfecb473ad23457d063b75eff29c0ffa2e58a9` |
| 512 bits (64 bytes) | `a8add4bdddfd93e4877d2746e62817b116364a1fa7bc148d95090bc7333b3673f82401cf7aa2e4cb1ecd90296e3f14cb5413f8ed77be73045b13914cdcd6a918` |

#### Single-byte inputs (BLAKE2b-512)

| Input (hex) | Hash |
|-------------|------|
| `00` | `2fa3f686df876995167e7c2e5d74c4c7b6e48f8068fe0e44208344d480f7904c36963e44115fe3eb2a3ac8694c28bcb4f5a0f3276f2e79487d8219057a506e4b` |
| `01` | `9545ba37b230d8a2e716c4707586542780815b7c4088edcb9af6a9452d50f32474d5ba9aab52a67aca864ef2696981c2eadf49020416136afd838fb048d21653` |
| `ff` | `eb65152dcb7b3371d6399005e2e0fac3e0858c5c51448384666abe437a03ad21ed359a62260552978ac341c00c57f1e1ca65af9e46bc57b37764c7cbf5119c44` |

#### Sequential input 0x00..0x3f (64 bytes, BLAKE2b-512)

```
2fc6e69fa26a89a5ed269092cb9b2a449a4409a7a44011eecad13d7c4b045660
2d402fa5844f1a7a758136ce3d5d8d0e8b86921ffff4f692dd95bdc8e5ff0052
```

#### Sequential inputs at various sizes (BLAKE2b-512)

Input: `bytes(range(N))` for N ≤ 256, or `bytes([i % 256 for i in range(N)])` for N > 256.

| Input length (bytes) | Hash |
|----------------------|------|
| 128 (0x00..0x7f) | `2319e3789c47e2daa5fe807f61bec2a1a6537fa03f19ff32e87eecbfd64b7e0e8ccff439ac333b040f19b0c4ddd11a61e24ac1fe0f10a039806c5dcc0da3d115` |
| 256 (0x00..0xff) | `1ecc896f34d3f9cac484c73f75f6a5fb58ee6784be41b35f46067b9c65c63a6794d3d744112c653f73dd7deb6666204c5a9bfa5b46081fc10fdbe7884fa5cbf8` |
| 512 | `c59ab1095ca4579525338b6b74689ff234bc3fe9765fe26dfb04ddceaee0ab84dfd8967594cb261fcd88687f4454d80f718116c1b3c32f9f7e169357468cbe67` |
| 1024 | `6b490f42e902f61b1ee12d3c85e34152e37c94d07ab9ea577cad6a6eb4690fad38064f53a19c225703a5c52cdc9a85add71b339d327e1630ee3432b920240e8a` |
| 4096 | `e26719386d1b390b6abe5eca9737a88a5f2cb365ce1bc7d4e3240a7f9f8177922b6ac82a9172ac4587463f7ef2192509d10eb8edd1d6f9d0962f7d06bf0c6b47` |

#### Sequential inputs at various sizes (BLAKE2b-256)

| Input length (bytes) | Hash |
|----------------------|------|
| 1 (0x00) | `03170a2e7597b7b7e3d84c05391d139a62b157e78786d8c082f29dcf4c111314` |
| 64 (0x00..0x3f) | `10d8e6d534b00939843fe9dcc4dae48cdf008f6b8b2b82b156f5404d874887f5` |
| 128 (0x00..0x7f) | `c3582f71ebb2be66fa5dd750f80baae97554f3b015663c8be377cfcb2488c1d1` |
| 256 (0x00..0xff) | `39a7eb9fedc19aabc83425c6755dd90e6f9d0c804964a1f4aaeea3b9fb599835` |

### BLAKE2b Keyed

Key for these vectors: sequential bytes 0x00..0x3f (64 bytes).

| Input | Output size | Hash |
|-------|-------------|------|
| empty | 512 bits | `10ebb67700b1868efb4417987acf4690ae9d972fb7a590c2f02871799aaa4786b5e996e8f0f4eb981fc214b005f42d2ff4233499391653df7aefcbc13fc51568` |
| "abc" | 512 bits | `06bbc3dedf13a31139498655251b7588ccd3bb5aaa071b2d44d8e0a04095579ed590fbfdcf941f4370ce5ce623624e7a76d33e7a8109dcda9b57d72f8f8efa51` |
| 0x00..0x3f (64 bytes) | 512 bits | `65676d800617972fbd87e4b9514e1c67402b7a331096d3bfac22f1abb95374abc942f16e9ab0ead33b87c91968a6e509e119ff07787b3ef483e1dcdccf6e3022` |

Shorter key example — key: `0123456789abcdef` (16 bytes, ASCII):

| Input | Output size | Hash |
|-------|-------------|------|
| "test message" | 256 bits | `2e2c5701b45c2052fad49e2572c83958e40be20df335a25e55213c6f6629311f` |

### BLAKE2b Salt and Personalization

| Input | Salt (16 bytes) | Personalization (16 bytes) | Output size | Hash |
|-------|------|-----------------|-------------|------|
| "data" | `saltsalt12345678` | `MyApp___v1.0____` | 256 bits | `ad0c7e9d37c24d505789156b4467778dd5ee49b3a5c9de53386ada6e7bc74428` |

---

## BLAKE2s

### BLAKE2s Unkeyed

#### Empty input

| Output size | Hash |
|-------------|------|
| 128 bits (16 bytes) | `64550d6ffe2c0a01a14aba1eade0200c` |
| 256 bits (32 bytes) | `69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9` |

#### Input: "abc" (0x616263)

| Output size | Hash |
|-------------|------|
| 128 bits (16 bytes) | `aa4938119b1dc7b87cbad0ffd200d0ae` |
| 256 bits (32 bytes) | `508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982` |

#### Input: "The quick brown fox jumps over the lazy dog"

| Output size | Hash |
|-------------|------|
| 256 bits (32 bytes) | `606beeec743ccbeff6cbcdf5d5302aa855c256c29b88c8ed331ea1a6bf3c8812` |

#### Sequential input 0x00..0x1f (32 bytes, BLAKE2s-256)

```
05825607d7fdf2d82ef4c3c8c2aea961ad98d60edff7d018983e21204c0d93d1
```

### BLAKE2s Keyed

Key: sequential bytes 0x00..0x1f (32 bytes).

| Input | Output size | Hash |
|-------|-------------|------|
| empty | 256 bits | `48a8997da407876b3d79c0d92325ad3b89cbb754d86ab71aee047ad345fd2c49` |
| "abc" | 256 bits | `a281f725754969a702f6fe36fc591b7def866e4b70173ece402fc01c064d6b65` |
| 0x00..0x1f (32 bytes) | 256 bits | `c03bc642b20959cbe133a0303e0c1abff3e31ec8e1a328ec8565c36decff5265` |
| empty | 128 bits | `9536f9b267655743dee97b8a670f9f53` |
| "abc" | 128 bits | `61ba5f165c194692e09d12520cc4c74a` |

Shorter key example — key: `secret` (6 bytes, ASCII):

| Input | Output size | Hash |
|-------|-------------|------|
| "test message" | 256 bits | `ceca2d0eb9eb415efb64c7167ed57ba8c552b39a7d0e0eea554793e380ca00e1` |

### BLAKE2s Sequential Inputs (BLAKE2s-256)

| Input length (bytes) | Hash |
|----------------------|------|
| 1 (0x00) | `e34d74dbaf4ff4c6abd871cc220451d2ea2648846c7757fbaac82fe51ad64bea` |
| 2 (0x00..0x01) | `ddad9ab15dac4549ba42f49d262496bef6c0bae1dd342a8808f8ea267c6e210c` |
| 4 (0x00..0x03) | `0cc70e00348b86ba2944d0c32038b25c55584f90df2304f55fa332af5fb01e20` |
| 8 (0x00..0x07) | `c7e887b546623635e93e0495598f1726821996c2377705b93a1f636f872bfa2d` |
| 16 (0x00..0x0f) | `efc04cdc391c7e9119bd38668a534e65fe31036d6a62112e44ebeb11f9c57080` |
| 64 (0x00..0x3f) | `56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e` |
| 128 (0x00..0x7f) | `1fa877de67259d19863a2a34bcc6962a2b25fcbf5cbecd7ede8f1fa36688a796` |
| 256 (0x00..0xff) | `5fdeb59f681d975f52c8e69c5502e02a12a3afcc5836ba58f42784c439228781` |

BLAKE2s-128 sequential inputs:

| Input length (bytes) | Hash |
|----------------------|------|
| 0 (empty) | `64550d6ffe2c0a01a14aba1eade0200c` |
| 1 (0x00) | `9f31f3ec588c6064a8e1f9051aeab90a` |
| 32 (0x00..0x1f) | `68b96e07fa73966ccefd87ccad489984` |
| 64 (0x00..0x3f) | `dc66ca8f03865801b0ffe06ed8a1a90e` |

---

## BLAKE2bp (4-way parallel BLAKE2b)

**Important**: BLAKE2bp produces **different output** from BLAKE2b for the same input. They are different algorithms. BLAKE2bp uses 4 parallel BLAKE2b instances with a tree structure.

Output size: 64 bytes (512 bits).

### BLAKE2bp Unkeyed

| Input | Hash |
|-------|------|
| empty | `b5ef811a8038f70b628fa8b294daae7492b1ebe343a80eaabbf1f6ae664dd67b9d90b0120791eab81dc96985f28849f6a305186a85501b405114bfa678df9380` |
| "abc" | `b91a6b66ae87526c400b0a8b53774dc65284ad8f6575f8148ff93dff943a6ecd8362130f22d6dae633aa0f91df4ac89aaff31d0f1b923c898e82025dedbdad6e` |
| "The quick brown fox jumps over the lazy dog" | `f10e0523631699102c63412c0701fa19f6550fbac0e9c035803c6033b50465222bb92ee0af0dad53edca32f0e08a72c077a6cafc6f4d24a7fb649079d47ce089` |
| 0x00..0x3f (64 bytes) | `6b9d86f15c090a00fc3d907f906c5eb79265e58b88eb64294b4cc4e2b89b1a7c5ee3127ed21b456862de6b2abda59eaacf2dcbe922ca755e40735be81d9c88a5` |
| 0x00..0x7f (128 bytes) | `05ad0f271faf7e361320518452813ff9fb9976ac378050b6eefb05f7867b577b8f14475794cff61b2bc062d346a7c65c6e0067c60a374af7940f10aa449d5fb9` |

### BLAKE2bp Keyed

Key: sequential bytes 0x00..0x3f (64 bytes).

| Input | Hash |
|-------|------|
| empty | `9d9461073e4eb640a255357b839f394b838c6ff57c9b686a3f76107c1066728f3c9956bd785cbc3bf79dc2ab578c5a0c063b9d9c405848de1dbe821cd05c940a` |
| "abc" | `8943f40e65e41fdbbe79b701b26279125bbe120379dd77d74fdb5faf662ed6a3974aa1dce99a3349a492159fa0ded8245a5167c11886170a3af12888448fa8b2` |
| 0x00..0x3f (64 bytes) | `22b8249eaf722964ce424f71a74d038ff9b615fba5c7c22cb62797f5398224c3f072ebc1dacba32fc6f66360b3e1658d0fa0da1ed1c1da662a2037da823a3383` |
| 0x00..0x7f (128 bytes) | `9280f4d1157032ab315c100d636283fbf4fba2fbad0f8bc020721d76bc1c8973ced28871cc907dab60e59756987b0e0f867fa2fe9d9041f2c9618074e44fe5e9` |

---

## BLAKE2sp (8-way parallel BLAKE2s)

**Important**: BLAKE2sp produces **different output** from BLAKE2s for the same input. They are different algorithms. BLAKE2sp uses 8 parallel BLAKE2s instances with a tree structure.

Output size: 32 bytes (256 bits).

### BLAKE2sp Unkeyed

| Input | Hash |
|-------|------|
| empty | `dd0e891776933f43c7d032b08a917e25741f8aa9a12c12e1cac8801500f2ca4f` |
| "abc" | `70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5` |
| "The quick brown fox jumps over the lazy dog" | `cf192976714bb648e72b29fa90e6bf0fbc5bf2efe7d5c26ed8ff34e855368691` |
| 0x00..0x3f (64 bytes) | `52603b6cbfad4966cb044cb267568385cf35f21e6c45cf30aed19832cb51e9f5` |
| 0x00..0x7f (128 bytes) | `05cf3a90049116dc60efc31536aaa3d167762994892876dcb7ef3fbecd7449c0` |

### BLAKE2sp Keyed

Key: sequential bytes 0x00..0x1f (32 bytes).

| Input | Hash |
|-------|------|
| empty | `715cb13895aeb678f6124160bff21465b30f4f6874193fc851b4621043f09cc6` |
| "abc" | `b334a26923410dc586088f365ce36a12bedd33e03c0f4a3808a716dca3a721f0` |
| 0x00..0x3f (64 bytes) | `1d3701a5661bd31ab20562bd07b74dd19ac8f3524b73ce7bc996b788afd2f317` |
| 0x00..0x7f (128 bytes) | `0c6ce32a3ea05612c5f8090f6a7e87f5ab30e41b707dcbe54155620ad770a340` |

---

## BLAKE3

All BLAKE3 vectors use 32-byte (256-bit) output unless otherwise specified.

### BLAKE3 Hash Mode

#### Named inputs

| Input | Hash |
|-------|------|
| empty (0 bytes) | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262` |
| "abc" | `6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85` |
| "IETF" (0x49455446) | `83a2de1ee6f4e6ab686889248f4ec0cf4cc5709446a682ffd1cbb4d6165181e2` |
| "The quick brown fox jumps over the lazy dog" | `2f1514181aadccd913abd94cfa592701a5686ab23f8df1dff1b74710febc6d4a` |

#### Sequential inputs: bytes([i % 251 for i in range(N)])

These use the official BLAKE3 test vector input pattern where each byte equals its index modulo 251.

| Input length (bytes) | Hash |
|----------------------|------|
| 0 | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262` |
| 1 | `2d3adedff11b61f14c886e35afa036736dcd87a74d27b5c1510225d0f592e213` |
| 2 | `7b7015bb92cf0b318037702a6cdd81dee41224f734684c2c122cd6359cb1ee63` |
| 3 | `e1be4d7a8ab5560aa4199eea339849ba8e293d55ca0a81006726d184519e647f` |
| 4 | `f30f5ab28fe047904037f77b6da4fea1e27241c5d132638d8bedce9d40494f32` |
| 8 | `2351207d04fc16ade43ccab08600939c7c1fa70a5c0aaca76063d04c3228eaeb` |
| 63 | `e9bc37a594daad83be9470df7f7b3798297c3d834ce80ba85d6e207627b7db7b` |
| 64 (one block) | `4eed7141ea4a5cd4b788606bd23f46e212af9cacebacdc7d1f4c6dc7f2511b98` |
| 65 | `de1e5fa0be70df6d2be8fffd0e99ceaa8eb6e8c93a63f2d8d1c30ecb6b263dee` |
| 128 | `f17e570564b26578c33bb7f44643f539624b05df1a76c81f30acd548c44b45ef` |
| 1023 | `10108970eeda3eb932baac1428c7a2163b0e924c9a9e25b35bba72b28f70bd11` |
| 1024 (one chunk) | `42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7` |
| 1025 | `d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444` |

#### Larger sequential inputs

| Input length (bytes) | Hash |
|----------------------|------|
| 2048 | `e776b6028c7cd22a4d0ba182a8bf62205d2ef576467e838ed6f2529b85fba24a` |
| 4096 | `015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969` |
| 8192 | `aae792484c8efe4f19e2ca7d371d8c467ffb10748d8a5a1ae579948f718a2a63` |
| 16384 | `f875d6646de28985646f34ee13be9a576fd515f76b5b0a26bb324735041ddde4` |
| 65536 | `68d647e619a930e7b1082f74f334b0c65a315725569bdc123f0ee11881717bfe` |
| 131072 | `306baba93b1a393cbd35172837c98b0f59a41f64e1b2682ae102d8b2534b9e1c` |

These larger inputs test multi-chunk processing (>1024 bytes), SIMD parallelism (>4096 bytes), and multi-threading thresholds (~128 KiB).

### BLAKE3 Keyed Hash Mode

Key: `000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f` (sequential bytes 0x00..0x1f, 32 bytes).

Input pattern: `bytes([i % 251 for i in range(N)])`.

| Input length (bytes) | Keyed Hash |
|----------------------|------------|
| 0 | `73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f` |
| 1 | `d08b45c6b127ee94f3f8527a0b82a5f80be1695a0eaec6022e772c0eb95a7e8b` |
| 2 | `3a771bec5c84aa7ad8c0e214a0598c1d7091113e60595bd2b6db9d4725955e6a` |
| 3 | `e5326c9674055c012371eb5e26424317732fee320660bdd86d4f719edd7caa29` |
| 4 | `ecc370c5be25c5de9f633943eeed5ebb22df19f35dac8a37389ef618798a9736` |
| 8 | `8493f7c4b5f5373035a1316f0ec81d498942ffd7ca4d50c9d43140ca8ec376a6` |
| 63 | `e471df92f6f7dee100138af7da29695906b0dc34ccde2142a730dd4ebcbc09cc` |
| 64 | `cfaf838ff320e0d87301dcba02b1a4bb397d65119f57403df2817a51d4025f9b` |
| 65 | `d8a45528bfa93a0d9b7bf4c840b68f64af0b9ad3d0bbd6c1421c2a4cf1cdf3b4` |
| 128 | `fe43a847dfccdfa5f070664fb8b51d7b906341ff81ac4adafbf6a3ffac564def` |
| 1023 | `da1f18069871512af22af9f13dc005800dfd52c55f42753b5ae718086fe2ee44` |
| 1024 | `f45a9249a627fdf1fcf13c0e6376f6a9a9b2056d6e1b5693a4b119a3453665f9` |
| 1025 | `82223147a9b804a0c3f9a921b8d8aee250d1a51bb76be72152e6d5e8f27349b3` |
| 2048 | `636bfa717d4f9fc3e59da9b2e5cce6a2b78eb70469c0fce49da38b5419892423` |
| 4096 | `e8c6e859e0480c4b062457defd04d2f4303b6cc280a0fe080ec5c4346a171937` |

### BLAKE3 Derive Key Mode

Context string: `"BLAKE3 2019-12-27 16:29:52 test vectors context"` (this is the context string used in the official BLAKE3 test vectors).

Input pattern: `bytes([i % 251 for i in range(N)])`.

| Input length (bytes) | Derived Key |
|----------------------|-------------|
| 0 | `2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d` |
| 1 | `b3e2e340a117a499c6cf2398a19ee0d29cca2bb7404c73063382693bf66cb06c` |
| 2 | `1f166565a7df0098ee65922d7fea425fb18b9943f19d6161e2d17939356168e6` |
| 3 | `440aba35cb006b61fc17c0529255de438efc06a8c9ebf3f2ddac3b5a86705797` |
| 4 | `f46085c8190d69022369ce1a18880e9b369c135eb93f3c63550d3e7630e91060` |
| 8 | `2b166978cef14d9d438046c720519d8b1cad707e199746f1562d0c87fbd32940` |
| 63 | `b6451e30b953c206e34644c6803724e9d2725e0893039cfc49584f991f451af3` |
| 64 | `a5c4a7053fa86b64746d4bb688d06ad1f02a18fce9afd3e818fefaa7126bf73e` |
| 65 | `51fd05c3c1cfbc8ed67d139ad76f5cf8236cd2acd26627a30c104dfd9d3ff8a8` |
| 128 | `81720f34452f58a0120a58b6b4608384b5c51d11f39ce97161a0c0e442ca0225` |
| 1023 | `74a16c1c3d44368a86e1ca6df64be6a2f64cce8f09220787450722d85725dea5` |
| 1024 | `7356cd7720d5b66b6d0697eb3177d9f8d73a4a5c5e968896eb6a689684302706` |
| 1025 | `effaa245f065fbf82ac186839a249707c3bddf6d3fdda22d1b95a3c970379bcb` |
| 2048 | `7b2945cb4fef70885cc5d78a87bf6f6207dd901ff239201351ffac04e1088a23` |
| 4096 | `1e0d7f3db8c414c97c6307cbda6cd27ac3b030949da8e23be1a1a924ad2f25b9` |

### BLAKE3 Extended Output (XOF)

BLAKE3 can produce output of any length. Shorter outputs are always prefixes of longer ones.

#### Hash mode XOF — empty input at various output lengths

| Output length | Output |
|---------------|--------|
| 32 bytes | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262` |
| 48 bytes | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262e00f03e7b69af26b7faaf09fcd333050` |
| 64 bytes | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a` |
| 96 bytes | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a26f5487789e8f660afe6c99ef9e0c52b92e7393024a80459cf91f476f9ffdbda` |
| 128 bytes | `af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262e00f03e7b69af26b7faaf09fcd333050338ddfe085b8cc869ca98b206c08243a26f5487789e8f660afe6c99ef9e0c52b92e7393024a80459cf91f476f9ffdbda7001c22e159b402631f277ca96f2defdf1078282314e763699a31c5363165421` |

Note: Each row is a prefix of the next — you can visually confirm the prefix property.

#### Hash mode XOF — "abc" at various output lengths

| Output length | Output |
|---------------|--------|
| 32 bytes | `6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85` |
| 48 bytes | `6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d851fb250ae7393f5d02813b65d521a0d49` |
| 64 bytes | `6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d851fb250ae7393f5d02813b65d521a0d492d9ba09cf7ce7f4cffd900f23374bf0b` |
| 128 bytes | `6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d851fb250ae7393f5d02813b65d521a0d492d9ba09cf7ce7f4cffd900f23374bf0bc08a1fb0b38ed276181ccbd9f7b7edbddf9f86404ad7929605f6ffa3fb1ac87983105f013384f2f11d38879c985d47003804b905f0c38975e28d36804bb60d8c` |

#### Keyed hash XOF — empty input

Key: `000102...1f` (sequential bytes 0x00..0x1f, 32 bytes).

| Output length | Output |
|---------------|--------|
| 32 bytes | `73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f` |
| 64 bytes | `73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f097a9b78582396441e22930e5c7c98fd07f896796c81420f14eb9812f0482857` |
| 128 bytes | `73492b19995d71cdb1e9d74decc09809eb732f1b00bc95c27cb15f9dd4d6478f097a9b78582396441e22930e5c7c98fd07f896796c81420f14eb9812f04828571ebaff5af3de2f693214152e1e3825fa4deeea0414483125b4d46ee75ca0b6e8602d0a3cacd8cf0850a291f18b46392f99c74b64e12ae2247592e33668bf6633` |

#### Keyed hash XOF — "data"

Key: `000102...1f` (sequential bytes 0x00..0x1f, 32 bytes).

| Output length | Output |
|---------------|--------|
| 64 bytes | `d956c75c05e12e484384c66b67c88e618a0a6c0a24efccd582df613bd13176b821a8f3f024f76d603e6a2ae4612ecda382bccead944a1de4fc36544b15af920c` |

#### Keyed hash XOF — "abc"

Key: `000102...1f` (sequential bytes 0x00..0x1f, 32 bytes).

| Output length | Output |
|---------------|--------|
| 32 bytes | `6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532` |
| 48 bytes | `6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532262aadc939980b41d88f3a131cbe697a` |
| 64 bytes | `6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532262aadc939980b41d88f3a131cbe697a43c524cecf91529743ed3eaf5a74ae5b` |
| 96 bytes | `6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532262aadc939980b41d88f3a131cbe697a43c524cecf91529743ed3eaf5a74ae5bdcca275d94a90839158cf1041ae2c37031346582ed3f31594430b4c26bd53c36` |
| 128 bytes | `6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532262aadc939980b41d88f3a131cbe697a43c524cecf91529743ed3eaf5a74ae5bdcca275d94a90839158cf1041ae2c37031346582ed3f31594430b4c26bd53c36059a31e4ded41720f0ac37eef9b00d8270e5c083cc0124693a459b7d1147bbda` |

#### Derive key XOF — "abc"

Context: `"BLAKE3 2019-12-27 16:29:52 test vectors context"`.

| Output length | Output |
|---------------|--------|
| 32 bytes | `221c3923b5f3358d596e6cbad6c20c2c63df740e7dc46a8f9ebab07d460ba827` |
| 48 bytes | `221c3923b5f3358d596e6cbad6c20c2c63df740e7dc46a8f9ebab07d460ba8274fc8eee10f12b87e1f03887a5b361be0` |
| 64 bytes | `221c3923b5f3358d596e6cbad6c20c2c63df740e7dc46a8f9ebab07d460ba8274fc8eee10f12b87e1f03887a5b361be091d1df00265c7e9fb6ccc81f7183c6a5` |
| 96 bytes | `221c3923b5f3358d596e6cbad6c20c2c63df740e7dc46a8f9ebab07d460ba8274fc8eee10f12b87e1f03887a5b361be091d1df00265c7e9fb6ccc81f7183c6a5d1a54175a1ec94451cd626154a990e93567b0500427826b11e94714c966ade5b` |
| 128 bytes | `221c3923b5f3358d596e6cbad6c20c2c63df740e7dc46a8f9ebab07d460ba8274fc8eee10f12b87e1f03887a5b361be091d1df00265c7e9fb6ccc81f7183c6a5d1a54175a1ec94451cd626154a990e93567b0500427826b11e94714c966ade5b2d07d652a5ab70e33951c128ed11b2f1700c64725c9a0b6f0f3439d418af40b7` |

#### Derive key XOF — empty input

Context: `"BLAKE3 2019-12-27 16:29:52 test vectors context"`.

| Output length | Output |
|---------------|--------|
| 32 bytes | `2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d` |
| 64 bytes | `2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d905630c8be290dfcf3e6842f13bddd573c098c3f17361f1f206b8cad9d088aa4` |
| 128 bytes | `2cc39783c223154fea8dfb7c1b1660f2ac2dcbd1c1de8277b0b0dd39b7e50d7d905630c8be290dfcf3e6842f13bddd573c098c3f17361f1f206b8cad9d088aa4a3f746752c6b0ce6a83b0da81d59649257cdf8eb3e9f7d4998e41021fac119deefb896224ac99f860011f73609e6e0e4540f93b273e56547dfd3aa1a035ba668` |

#### XOF prefix property

**Shorter outputs are always exact prefixes of longer outputs.** This is by design — BLAKE3 does not domain-separate by output length. Verified example with input "test data":

| Output length | Output |
|---------------|--------|
| 32 bytes | `6a953581d60dbebc9749b56d2383277fb02b58d260b4ccf6f119108fa0f1d4ef` |
| 64 bytes | `6a953581d60dbebc9749b56d2383277fb02b58d260b4ccf6f119108fa0f1d4efd5bcf0bf18556989a0ab651aa166629593c8b809c5cd0f691944eeda1ceb36de` |
| 128 bytes | `6a953581d60dbebc9749b56d2383277fb02b58d260b4ccf6f119108fa0f1d4efd5bcf0bf18556989a0ab651aa166629593c8b809c5cd0f691944eeda1ceb36de2a2b4951295c6c12885fc8e1cf5b5e54e0cfda85a6026e18b3c0b25c605db97d0d1d19696e7355ed63307b069152096db2781b6bbf681e1fb11127a8c5faddd2` |

---

## Cross-Algorithm Comparison

Same input ("abc") across all algorithms, useful for verifying you're calling the right one:

| Algorithm | Output size | Hash of "abc" |
|-----------|-------------|---------------|
| BLAKE2b-256 | 32 bytes | `bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319` |
| BLAKE2b-384 | 48 bytes | `6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4` |
| BLAKE2b-512 | 64 bytes | `ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923` |
| BLAKE2s-128 | 16 bytes | `aa4938119b1dc7b87cbad0ffd200d0ae` |
| BLAKE2s-256 | 32 bytes | `508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982` |
| BLAKE2bp | 64 bytes | `b91a6b66ae87526c400b0a8b53774dc65284ad8f6575f8148ff93dff943a6ecd8362130f22d6dae633aa0f91df4ac89aaff31d0f1b923c898e82025dedbdad6e` |
| BLAKE2sp | 32 bytes | `70f75b58f1fecab821db43c88ad84edde5a52600616cd22517b7bb14d440a7d5` |
| BLAKE3 | 32 bytes | `6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85` |

### Keyed cross-algorithm comparison

Same input ("abc") with sequential keys across all keyed algorithms:

| Algorithm | Key | Output size | Keyed hash of "abc" |
|-----------|-----|-------------|---------------------|
| BLAKE2b keyed | 0x00..0x3f (64 bytes) | 512 bits | `06bbc3dedf13a31139498655251b7588ccd3bb5aaa071b2d44d8e0a04095579ed590fbfdcf941f4370ce5ce623624e7a76d33e7a8109dcda9b57d72f8f8efa51` |
| BLAKE2s keyed | 0x00..0x1f (32 bytes) | 256 bits | `a281f725754969a702f6fe36fc591b7def866e4b70173ece402fc01c064d6b65` |
| BLAKE2bp keyed | 0x00..0x3f (64 bytes) | 512 bits | `8943f40e65e41fdbbe79b701b26279125bbe120379dd77d74fdb5faf662ed6a3974aa1dce99a3349a492159fa0ded8245a5167c11886170a3af12888448fa8b2` |
| BLAKE2sp keyed | 0x00..0x1f (32 bytes) | 256 bits | `b334a26923410dc586088f365ce36a12bedd33e03c0f4a3808a716dca3a721f0` |
| BLAKE3 keyed_hash | 0x00..0x1f (32 bytes) | 256 bits | `6da54495d8152f2bcba87bd7282df70901cdb66b4448ed5f4c7bd2852b8b5532` |

---

## Using These Vectors

### Verification workflow

1. Pick the algorithm and mode that matches your implementation
2. Start with the **empty input** vector — it catches initialization errors
3. Test **"abc"** — catches basic input processing bugs
4. Test **boundary cases** (e.g., BLAKE3 at 64 and 1024 bytes) — catches off-by-one errors at block/chunk boundaries
5. Test **keyed** mode if your implementation supports it — catches key handling bugs
6. Compare against the **cross-algorithm table** to make sure you're using the right algorithm

### Input pattern for sequential vectors

The BLAKE3 sequential vectors use `bytes([i % 251 for i in range(N)])` — each byte is its index modulo 251 (a prime). In different languages:

```python
# Python
data = bytes([i % 251 for i in range(N)])
```

```rust
// Rust
let data: Vec<u8> = (0..n).map(|i| (i % 251) as u8).collect();
```

```c
// C
uint8_t data[N];
for (int i = 0; i < N; i++) data[i] = i % 251;
```

```go
// Go
data := make([]byte, n)
for i := range data { data[i] = byte(i % 251) }
```

The BLAKE2 keyed vectors use sequential byte keys: `0x00, 0x01, ..., 0x3f` (64 bytes for BLAKE2b) or `0x00, ..., 0x1f` (32 bytes for BLAKE2s).

### Additional test vectors

For exhaustive testing beyond what's listed here:
- BLAKE2: Official repo at `github.com/BLAKE2/BLAKE2/tree/master/testvectors` contains 256 keyed test vectors per variant
- BLAKE3: Official `test_vectors.json` at `github.com/BLAKE3-team/BLAKE3/blob/master/test_vectors/test_vectors.json` contains vectors at many more input sizes, including extended output
