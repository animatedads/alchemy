# Missing work — Messaging & Presence / XMPP / BOSH

Checked 2026-10-29.

This list is deliberately limited to work that cannot be honestly closed from the current repository and Library evidence.

1. **Socket Provider dev16 source publication**
   - Current external authority: `oorexx_socket_provider_v0.1-dev16.zip`.
   - SHA-256: `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.
   - The first-class GitHub tree still identifies itself as dev14.
   - Required action: publish/verify the exact dev16 source. Do not relabel dev14 source.

2. **Instrumentation Mesh dev8 source publication**
   - Current external authority: `oorexx_instrumentation_mesh_v0.1-dev8.zip`.
   - SHA-256: `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`.
   - Required action: publish exact first-class runtime source. Do not reconstruct it from older vendored copies.

3. **Fresh BOSH dev6 current-baseline execution**
   - The stale runner is repaired.
   - Required action: execute it with exact Socket Provider dev16, Instrumentation Mesh dev8 and ooRexx r13196 roots and retain the resulting evidence.

4. **Generic same-stream STARTTLS**
   - XMPP protocol state is implemented and fail-closed.
   - Current evidence does not prove a generic shared-provider same-stream TLS-upgrade seam.
   - Required action: qualify an explicit lower transport/TLS operation before enabling XMPP SASL over STARTTLS.

5. **Runtime qualification of integrated BOSH/API Client and SocketProvider seams**
   - `oorexx_bosh_api_client_adapter` is integrated on `main` at squash merge `12077975acaa9610ad1c696a703ce9f698b928ad`.
   - `oorexx_api_client_socket_provider_adapter` is integrated on `main` through dev2; dev3 candidate adds exact post-selection route admission.
   - RxSock remains the API Client default. The provider adapter preserves the exact selected `SocketAddress` and fails closed unless native `SELECT`, `PUMP` or `POLL` readiness exists.
   - Required action: run the deterministic suites under ooRexx r13196, including dev3 missing/mismatched-route-evidence negatives.
   - Current XTP context is dev34, with per-service protection using LDAP Identity Directory / Secret Broker key sources and multipath protection.
   - Do not add XTP selection or XTP security semantics to BOSH/API Client. A deployment policy may require exact lower-route evidence via the generic dev3 admission seam.

6. **Live private-CA HTTPS over XTP**
   - The architecture now has all source seams: BOSH -> API Client HTTP/HTTPS -> API Client TLS -> Socket Intention -> route admission -> SocketProvider -> XTP/TCP.
   - Required action: bind a real current XTP dev34 route through SocketProvider, supply attested lower-route evidence from the owning platform authority, and execute API Client TLS with the estate private CA over that carrier.
   - HTTPS/private-CA identity and XTP per-service protection are independent layers; neither substitutes for the other.
   - ConnectSelector dev8's authenticated invocation-route policy remains a separate authority and must not be copied into this adapter.

7. **Rasen Falcon sphere-checker configuration**
   - GitHub sphere content exists and the authenticated Rasen Falcon lane `messaging-presence` links the sphere artifact.
   - Current authenticated Rasen Falcon `sphere_check` returns `SPHERE_CHECKER_UNAVAILABLE`: no checker is configured in that deployment.
   - Required action: configure/enable the sphere checker, then validate the linked sphere.
