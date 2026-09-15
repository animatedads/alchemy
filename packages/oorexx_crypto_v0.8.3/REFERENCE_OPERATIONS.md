# Crypto v0.8 Runtime Reference operations

All operations in this release are `PURE`. Crypto v0.8 places `RuntimeExactBytes` in the SHA `data_hex` request slot for resident providers; RuntimeTcpJsonProvider v0.4 serializes that value to the same tagged hexadecimal wire text used by earlier releases. Integer values cross the JSON wire as base-10 strings to avoid JSON numeric precision loss. The TCP protocol remains `runtime.reference/0.1`; the Runtime Reference component API used for qualification is `runtime.reference/0.4`.


## SHA-256

- `crypto.sha256.digest/1`
  - args: `data_hex` as tagged exact-byte text `hex:<lowercase-hex>`
  - value: 64-character lowercase hexadecimal SHA-256 digest

The local consumer validates digest length and hexadecimal syntax before accepting a completed provider result. An invalid completed result is recorded as `RESULT_VALIDATION_FAILED` and falls back to the native streaming SHA-256 implementation. The tagged prefix prevents an all-decimal hexadecimal payload from being serialized by the ooRexx JSON library as a JSON number.


## SHA-512

- `crypto.sha512.digest/1`
  - args: `data_hex` as tagged exact-byte text `hex:<lowercase-hex>`
  - value: 128-character lowercase hexadecimal SHA-512 digest

The public streaming facade is unchanged. When a Runtime Reference switch is installed at construction time, updates are retained until `digest()` and the whole PURE digest is delegated. Provider output is validated locally for exact length and lowercase hexadecimal syntax. Unavailable/unsupported providers and invalid completed values fall back to the native streaming SHA-512 implementation when the Runtime Reference evidence says fallback is safe.


## HMAC-SHA-512

- `crypto.hmac.sha512.digest/1`
  - args: `key_hex`, `message` (exact bytes in-process; tagged hex on TCP)
  - value: 128-character lowercase HMAC-SHA-512 hex

The operation is whole-MAC and PURE. Completed provider results are length/hex validated before acceptance; native HMAC remains final fallback.

## ChaCha20

- `crypto.chacha20.crypt/1`
  - args: `data` (exact bytes), `key_hex` (32 bytes), `nonce_hex` (12 bytes)
  - value: exact output bytes

The provider preserves the inherited counter-1 stream semantics. Encrypt/decrypt continue to use the same public facade.

## Edwards25519

- `crypto.edwards25519.add/1`
  - args: `x`, `y`, `qx`, `qy`
  - value: `{x,y}`
- `crypto.edwards25519.multiply/1`
  - args: `x`, `y`, `scalar`
  - value: `{x,y}`

Returned points are locally validated for integer syntax, field range, and curve membership.

## Whole Ed25519

- `crypto.ed25519.keypair/1`
  - args: `seed_hex`
  - value: `{private, public, scalar}`
- `crypto.ed25519.sign/1`
  - args: `message`, `private_hex`
  - value: 128-character signature hex
- `crypto.ed25519.verify/1`
  - args: `message`, `signature_hex`, `public_hex`
  - value: string `true` or `false`

These operation boundaries allow the full public Ed25519 call to move to an optimized provider rather than only moving inner curve arithmetic.


## Experimental Ed448

- `crypto.ed448.keypair/1`
  - args: `seed_hex` (57 bytes)
  - value: `{private, public, scalar}`

This is deliberately the package's existing experimental SHA-512/clamp/Goldilocks keypair semantics, **not** a substitution of OpenSSL/RFC Ed448. The Foreign provider reproduces the native result exactly.

## X25519

- `crypto.x25519.public_key/1`
  - args: `private_scalar`
  - value: integer string
- `crypto.x25519.shared_secret/1`
  - args: `my_private`, `their_public`
  - value: integer string

Values must be in `[0, 2^255-19)`. The Foreign implementation intentionally preserves the package's current unclamped scalar semantics rather than substituting standard EVP X25519 clamping.

## RSA

The provider must preserve the existing textbook/reference RSA semantics.

- `crypto.rsa.keypair/1`
  - args: `p`, `q`, `e`
  - value: `{n,e,d,phi}`
  - local validation recomputes `n=p*q`, `phi=(p-1)(q-1)`, and verifies `e*d mod phi = 1`.

- `crypto.rsa.generate_keypair/1`
  - args: `e`
  - value: `{n,e,d,phi}`
  - the test provider uses OpenSSL-backed 2048-bit prime generation, then derives `d` using Crypto's exact `phi(n)` convention.

- `crypto.rsa.encrypt/1`
  - args: `plaintext_hex`, `e`, `n`
  - value: ciphertext integer string
  - plaintext is transported as hex so arbitrary ooRexx bytes are not silently changed by JSON text encoding.

- `crypto.rsa.decrypt/1`
  - args: `ciphertext`, `d`, `n`
  - value: plaintext hex

- `crypto.rsa.sign/1`
  - args: `message_int`, `d`, `n`
  - value: signature integer string

- `crypto.rsa.verify/1`
  - args: `signature`, `e`, `n`
  - value: recovered integer string (matching the inherited API; this is not a boolean verifier).

## Foreign Runtime execution mapping

With `.CryptoForeignRuntimeInstaller~install`, the semantic operation ids above are unchanged. Standard operations are implemented directly from `openssl_direct.bridge.json` against system libcrypto. `openssl_compat.bridge.json` / `libcrypto_compat.so` is consulted only for Edwards25519 add/multiply, current unclamped X25519, and experimental Ed448 keypair. The two foreign definitions are independently lazy-loaded and independently fail-safe.

## Deployment hook

```rexx
.CryptoLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch
```

With the switch `.nil`, all operations remain wholly native. The development Python service intentionally transports private key material only to prove equivalence/performance; production deployments should use secure/provider-owned private-key references where appropriate.
