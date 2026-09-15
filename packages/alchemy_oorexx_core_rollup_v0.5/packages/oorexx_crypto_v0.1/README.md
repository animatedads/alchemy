# ooRexx Crypto v0.1

`oorexx_crypto_v0.1` is the single shared cryptographic primitive package for the current ooRexx library line. Consumers should resolve `crypto.cls` from this package rather than carrying private copies.

## Provenance

The starting `crypto.cls` is the byte-identical source previously vendored by Queue Fabric v0.8.1, Runtime Registry v0.11 and Work Load Units v0.2:

- original SHA-256: `b56e5e3d7547abc1202d200bfbb79b3e9df6523173cb95a35e47b0ad10c3e395`

v0.1 promotes that source into its own package and then makes two deliberate classes of change:

1. shared keyed-authentication primitives are added (`HMACSHA512`, `SipHash128`, `CryptoMacProof`, `CryptoMacKeyRing`, `CryptoUtils`), including the SipHash-2-4-128 implementation first exercised by WLU;
2. the existing ChaCha20 implementation is corrected to match RFC 8439 by loading key/nonce words little-endian and by deep-copying the initial state instead of using ooRexx stem aliasing (`x. = s.`).

No consumer is expected to edit or vendor this file after v0.1.

## Supported trust-path primitives

The current library stack relies on:

- SHA-512;
- Ed25519 verification/signing at portable trust/checkpoint boundaries;
- HMAC-SHA-512 where an existing subsystem requires that MAC;
- SipHash-2-4-128 for high-frequency short-record authentication inside a shared-key trust domain.

SipHash is a MAC/PRF, not a public-key signature. Its proof records carry an algorithm id and key id so key rotation does not change the record format.

## Other inherited primitives

`crypto.cls` also contains MD5, X25519 arithmetic, ChaCha20, RSA/reference helpers, Ed448-related experimental helpers and `CryptoStream` compatibility code. The tests deliberately distinguish externally validated primitives from legacy/reference helpers:

- MD5 is tested for compatibility only and must not be used as a security hash.
- X25519 key-agreement arithmetic receives a symmetry test. The inherited `X25519~encryptStream/decryptStream` construction is non-standard and is **not** part of the supported security surface in v0.1.
- RSA is textbook/reference RSA without modern padding; it is not a replacement for a production RSA signature/encryption scheme.
- the inherited Ed448 code explicitly does not implement RFC 8032 Ed448 (it uses SHA-512 where RFC Ed448 requires SHAKE256) and is not advertised as a supported signing path.
- `CryptoStream` remains compatibility/reference code; current Runtime Registry, Queue Fabric and WLU trust paths do not depend on it.

## Running the tests

```sh
REXX=/path/to/rexx ./run_tests.sh
```

The suite covers:

- MD5 and SHA-512 known answers plus streaming behaviour;
- RFC 4231 HMAC-SHA-512;
- SipHash-2-4-128 reference vectors, tamper rejection and key rotation;
- RFC 8032 Ed25519 key generation/sign/verify vector 1;
- RFC 8439 ChaCha20 encryption vector and round-trip;
- X25519 Diffie-Hellman symmetry;
- textbook RSA arithmetic/sign/verify smoke coverage;
- malformed key/tag rejection.

`benchmarks/benchmark_fast_mac.rex` is informational and has no timing pass/fail threshold.

## Consumer integration

The companion patch releases use this package explicitly:

- Work Load Units v0.2.1;
- Queue Fabric v0.8.2;
- Runtime Registry v0.11.1;
- Legal Effect v0.10.1 (for its optional SHA-512/Ed25519 bridge).

Their test runners accept `CRYPTO_SRC` or `OOREXX_CRYPTO_SRC` pointing at this package's `src/` directory. This is intentional: a missing shared crypto dependency should fail visibly rather than fall back to a stale local copy.
