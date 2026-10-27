# Alchemy source provenance: `oorexx_quic_socket_provider`

- Development delivery: `oorexx_quic_socket_provider_v0.1-dev4.zip`
- Delivery SHA-256: `51464ddea2dec56557a8ea7f806fe8f54933da99527b249a67da2e74f3fde63b`
- Development status: source/static-qualified in the 2026-10-27 packaging environment; ooRexx/native live qualification not rerun because the r13196 runtime/header package was not mounted.
- Last live-qualified baseline: `oorexx_quic_socket_provider_v0.1-dev3.zip`, SHA-256 `34a224252f33079cdbe78d4e5f6f122c0cdd6524364f92e95da36bc233b54749`.
- Native backend: OpenSSL QUIC / TLS 1.3.
- Dev4 delta: nonblocking stream creation under stream-count flow control plus local bidirectional/unidirectional stream allowance observation.

## Qualification boundary

The dev4 OpenSSL API subset was compiled against OpenSSL 3.5.5 and package/static checks passed. This is not a replacement for the dev3 live TLS 1.3 loopback and two-stream multiplex evidence. Run `qualification/run_environment_test.sh` with ooRexx 5.3.0 r13196 before promoting dev4 to the live-qualified baseline.

## Generated/private material

Generated qualification certificates, private keys, logs and the native `.so` are not source and are not retained in the GitHub source tree. Rebuild the native library with `make` against the intended ooRexx/OpenSSL environment.
