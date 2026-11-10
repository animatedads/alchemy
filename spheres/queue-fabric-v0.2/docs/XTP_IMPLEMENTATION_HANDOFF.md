# Queue Fabric optional XTP integration (23 October 2026)
Status: engineering handoff; NO Queue Fabric-over-XTP acceptance.
Source: Queue Fabric dev6 4477733b121dc540b3325a834cd99a2665b07dc468e09181dd7aa8f01b728d40; XTP dev25 7f6ab3d1167d5fd3131c7e6d6e9ea8d8c6115106ea9df89d41357ef56773b80b; Planner dev5 422dd2a2f2ef03ab9376e7e3f7ed9a847eb6212cf03eeba84a909ccd133b5479; Memory Fabric XTP candidate2 8ff6370826c29929292559899adf8222c5ed2a0f86d67a139dc01d312693d57d; XTP Gopher sphere cef809f47e97a246c38ef00ec37befdb5ca844ff995b42fbe07282778d0c8195.

## Boundaries
Queue Fabric owns objects, queue/transmission intent, CLAIM/RELEASE, authenticated queue.transport/2 peer and channel ACL, UOW, idempotency, receiver transferId and per-manager durable receipts.
XTP owns named FIRST admission, KEY/ROUTE transport replay, physical carrier path selection, multicast ACK/quorum, receiver RATE/BURST and optional per-context capacityRate.
Planner owns named capacity domains and live admission tickets. Service Descriptors own canonical service to logical peer and operational class mapping, not transport endpoints.
ConnectSelector/SocketSelector remain the generic route/provider boundaries. Existing TCP/TLS and other qualified sockets remain first class.

## Executable missing work
1. Implement a capability-aware Queue Fabric channel adapter using actual provider APIs. Do not fork the manager, journal or queue.transport/2 wire.
2. Apply XTP named-service registration, pre-ACK admission, then separately authenticate the remote queue manager and enforce channel/queue ACL.
3. Preserve transferId across transport context KEY changes; channel retry RELEASE does not increment application backoutCount.
4. Bind interested queue-manager generation to approved reliable multicast groups. XTP quorum does NOT confirm durable Queue Fabric UOW. Keep intents until durable per-manager receipt; repair missing managers idempotently.
5. Admit capacity/WLU before CLAIM; refresh or suspend live contexts under Planner dev5 capacity contraction; apply sender ticket rate and receiver RATE/BURST.
6. Run real two-process, crash/restart and ED209 directed carrier tests. No automatic cross-cloud multicast or unauthenticated/NOERR fallback.

Route publication xtp.provision is still an offline authority proposal. The independently owned XTP sphere remains authoritative for XTP transport/provisioning, not this Queue Fabric integration note.
