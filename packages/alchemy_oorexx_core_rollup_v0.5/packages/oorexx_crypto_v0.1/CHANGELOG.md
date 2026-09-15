# Changelog

## v0.1

- Establishes the standalone authoritative `crypto.cls` package from the byte-identical source previously vendored in Queue Fabric v0.8.1, Runtime Registry v0.11 and WLU v0.2.
- Adds generic HMAC-SHA-512 and SipHash-2-4-128 keyed authentication primitives.
- Adds generic MAC proof/key-ring helpers and shared non-early-exit equality helper.
- Moves the WLU fast-MAC algorithm out of WLU ownership; WLU retains only domain-specific compatibility/proof classes.
- Fixes inherited ChaCha20 RFC 8439 conformance: little-endian key/nonce word loading and independent working-state copy instead of ooRexx stem aliasing.
- Adds an independent cryptographic test battery with external known-answer vectors and adversarial/tamper checks.
- Documents inherited non-standard/legacy helper surfaces that are not part of the supported enterprise trust path.
