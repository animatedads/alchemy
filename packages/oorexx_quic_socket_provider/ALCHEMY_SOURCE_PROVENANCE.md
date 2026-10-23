# Alchemy source provenance: `oorexx_quic_socket_provider`

- Source delivery: `oorexx_quic_socket_provider_v0.1-dev3.zip`
- Delivery SHA-256: `34a224252f33079cdbe78d4e5f6f122c0cdd6524364f92e95da36bc233b54749`
- Qualification runtime: ooRexx 5.3.0 r13196
- Native backend: OpenSSL QUIC / TLS 1.3
- Live evidence: binary-safe connection round-trip plus two independent bidirectional child streams on one QUIC connection.

## GitHub admission corrections

The sealed dev3 delivery is the qualification provenance.  During repository
admission two stale labels were found and corrected:

- `QuicSocketProviderBuild.VERSION`: `0.1-dev2` -> `0.1-dev3`
- `docs/ARCHITECTURE.md` heading: `dev2` -> `dev3`

These are source-identity/documentation corrections only; they do not upgrade or
alter the observed dev3 transport evidence.

## Omitted generated/private material

- `.qualification/server.key`, generated certificates and qualification logs
  are transient and are not source.
- `lib/liboorexx_quic_native.so` is a generated native build artifact and is
  not retained in the corrected GitHub source tree.  Rebuild it with `make`
  against the intended ooRexx/OpenSSL environment.
