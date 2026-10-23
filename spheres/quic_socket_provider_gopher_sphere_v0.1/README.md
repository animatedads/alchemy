# ooRexx QUIC Socket Provider Gopher Sphere v0.1

Authoritative continuity sphere for the ooRexx QUIC Socket Provider.

This sphere records the durable architecture behind `oorexx_quic_socket_provider`: QUIC is a sibling socket family behind the shared `SocketProvider` / `SocketSelector` boundary; applications do not select QUIC by constructing protocol-specific transports; `QuicSocketAddress` remains a full object; security material is referenced through a provider-owned security profile rather than embedded in addresses; OpenSSL owns QUIC/TLS 1.3 protocol mechanics; and QUIC multiplexing is additive through child `QuicStream` objects while the ordinary `SocketStreamAdapter` path remains valid.

Current grounded source release: `oorexx_quic_socket_provider_v0.1-dev3.zip`, SHA-256 `34a224252f33079cdbe78d4e5f6f122c0cdd6524364f92e95da36bc233b54749`.

Current reconciliation evidence records QUIC dev3 live-qualified against the Socket Provider dev16 estate with TLS 1.3 loopback and two-stream multiplexing. The dev3 package itself was built against the dev14 common contract; this is compatible evidence, not permission to rewrite package history.

Start with `packs/quic-socket-provider/00-sphere.json` and the articles listed in `start_here`.
