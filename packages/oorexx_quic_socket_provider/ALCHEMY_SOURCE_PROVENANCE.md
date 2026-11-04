# Alchemy source provenance: `oorexx_quic_socket_provider`

- Current Git development source: `0.1-dev5`.
- Last packaged development delivery: `oorexx_quic_socket_provider_v0.1-dev4.zip`, SHA-256 `51464ddea2dec56557a8ea7f806fe8f54933da99527b249a67da2e74f3fde63b`.
- Last fully live-qualified delivery: `oorexx_quic_socket_provider_v0.1-dev3.zip`, SHA-256 `34a224252f33079cdbe78d4e5f6f122c0cdd6524364f92e95da36bc233b54749`.
- Native backend: OpenSSL QUIC / TLS 1.3.
- Dev5 delta: structured child-stream nonblocking I/O results preserving QUIC WANT_READ/WANT_WRITE flow-control states.

## Qualification boundary

Dev5 source and tests are committed, but the ooRexx 5.3.0 r13196 runtime/header package is not mounted in this execution container, so the native rebuild and live TLS/multiplex suite are not claimed here. Dev3 remains the live-qualified baseline until the environment suite is rerun.

## Generated/private material

Generated qualification certificates, private keys, logs and native shared libraries are not source.
