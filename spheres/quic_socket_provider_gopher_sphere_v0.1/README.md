# ooRexx QUIC Socket Provider Gopher Sphere v0.1

Authoritative continuity sphere for the ooRexx QUIC Socket Provider.

This sphere records the durable architecture behind `oorexx_quic_socket_provider`: QUIC is a sibling socket family behind the shared `SocketProvider` / `SocketSelector` boundary; applications do not select QUIC by constructing protocol-specific transports; `QuicSocketAddress` remains a full object; security material is referenced through a provider-owned security profile rather than embedded in addresses; OpenSSL owns QUIC/TLS 1.3 protocol mechanics; and QUIC multiplexing is additive through child `QuicStream` objects while the ordinary `SocketStreamAdapter` path remains valid.

Current development release: `oorexx_quic_socket_provider_v0.1-dev4.zip`, SHA-256 `51464ddea2dec56557a8ea7f806fe8f54933da99527b249a67da2e74f3fde63b`. The last live-qualified release remains dev3 (`34a224252f33079cdbe78d4e5f6f122c0cdd6524364f92e95da36bc233b54749`).

Current reconciliation evidence records QUIC dev3 live-qualified against the Socket Provider dev16 estate with TLS 1.3 loopback and two-stream multiplexing. Dev4 adds stream-count backpressure semantics but is currently source/static-qualified only; it must not inherit dev3's live status until the r13196/native suite is rerun.

Start with `packs/quic-socket-provider/00-sphere.json` and the articles listed in `start_here`.
