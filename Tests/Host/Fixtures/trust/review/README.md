# Independent review fixtures (26 Nov 2026)

Made by the independent review of `Sources/Core/HCGOpenPGP.m` with GnuPG 2.4 and small packet-rewriting scripts.
Throwaway 2048-bit test key `6DE8 6F7C 180F 9EA1 82E4  49DA 9A94 D752 B5FB 1219` (signing subkey `3B345F593EF54644`);
its private key was never kept. Each file was a way to get a wrong answer before the fix in 0.6.0; the expected
answers are in `Tests/Host/TrustReviewTests.m`.

| File | What it is | Before | Now |
|---|---|---|---|
| `key.bin`, `Release`, `Release.sig`, `InRelease` | baseline | Good | Good |
| `D_rev.bin` | signing subkey revoked (SHA-512) | Revoked | Revoked |
| `D_dup.bin` | the revoked subkey listed twice, the first copy without its revocation | **Good** | Revoked |
| `D_sha1rev.bin` | the subkey revoked with a SHA-1 revocation | **Good** | Revoked |
| `D_stripped.bin` | the revocation packet removed | **Good** | Revoked when this iPhone has seen the revocation before |
| `dos_8192_8192.bin`, `dos_16384_16384.bin`, `dos_max.bin` | huge modulus and exponent with a self-signature whose hash prefix is right | 2.5 s / 20 s / ~20 min of CPU | refused at once |
| `B_critnot.sig`, `B_critpol.sig` | critical notation / policy URL | **Good** | Unsupported |
| `A_trailing.sig`, `A_litpkt.sig` | bytes / a literal packet after a good signature | **Good** | Malformed |
| `F_binary_in_clear.txt` | a binary-mode (0x00) signature inside a signed message | **Good** | Malformed |
| `fpr` | primary fingerprint | | |
