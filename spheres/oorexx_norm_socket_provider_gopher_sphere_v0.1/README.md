# ooRexx NORM Socket Provider Gopher Sphere v0.1

Authoritative continuity sphere for NRL NORM as an ordinary ooRexx SocketProvider family.

The sphere records the boundary established by `oorexx_norm_v0.1-dev3`: applications describe semantic socket requirements and retain full `SocketAddress` objects; SocketSelector chooses a qualified provider; NORM-specific instance/session, multicast membership, SSM, NACK/FEC, descriptor/event and UDP/IP wire mechanics terminate below that common boundary.

Current grounded NORM source release: `oorexx_norm_v0.1-dev3.zip`, SHA-256 `d997007d35c7527eb40d6d62516cee036ed2d1a27fb1edbe32bdf4389abcd231`.

Current common socket authority is `oorexx_socket_provider_v0.1-dev16.zip`, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`. NORM dev3 was originally developed against dev10 and was subsequently live-requalified against dev16 on 2026-10-10. That is compatibility evidence, not a retroactive rewrite of the dev3 package history.

Current sibling XTP development head is dev25; XTP route/multipath/multicast mechanics remain XTP-owned and do not alter NORM's provider boundary.

Event Runtime integration is being carried as the separate transport-neutral `oorexx_socket_event_runtime_adapter_v0.1-dev1` candidate. It consumes SocketProvider descriptor/readiness/tryAccept and emits `SOCKET.ACCEPTED` through Event Runtime v0.1-dev1 without adding polling to Event Runtime or NORM-specific methods to the common socket contract. NORM dev3 remains the live-qualified transport baseline until that adapter candidate is independently executed.

Start with `packs/norm-socket-provider/00-sphere.json` and the articles listed in `start_here`.
