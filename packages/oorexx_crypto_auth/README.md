# ooRexx Crypto Authentication Primitives v0.1-dev1

A narrow companion extension to `oorexx_crypto_v0.8.3` for authentication standards.
It adds SHA-1 solely for standards interoperability and generic HMAC-SHA-1 / HMAC-SHA-256 / HMAC-SHA-512 surfaces. Existing SHA-256 and SHA-512 remain owned by `crypto.cls`.

Public API: `crypto.auth/0.1`.

This is intended to be upstreamed into the main Crypto authority rather than becoming a competing cryptography library.
