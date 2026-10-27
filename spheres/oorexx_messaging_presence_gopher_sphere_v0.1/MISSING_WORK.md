# Missing work — Messaging & Presence / XMPP / BOSH

Checked 2026-10-27.

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

5. **BOSH/API Client adapter qualification and lower selector backend**
   - API Client v0.4.1 is the authoritative outbound HTTP/HTTPS client and the new separate `oorexx_bosh_api_client_adapter` source candidate binds `BoshHttpExchangeProvider` to `ApiRequest` / `ApiResponse`.
   - The candidate is rebased onto current main, preserves rich ooRexx header/route objects, denies cleartext HTTP by default, and has no XMPP/SocketProvider/XTP dependency.
   - Required action: execute its deterministic test under ooRexx r13196 and current exact roots, then qualify live HTTPS.
   - HTTPS-over-XTP remains lower-layer work because API Client v0.4.1 currently documents RxSock socket ownership. Add/qualify a shared SocketProvider/selector backend there; do not put XTP knowledge into BOSH or this adapter.

6. **Sphere registration**
   - GitHub sphere content exists.
   - Current LLM Gopher `sphere_check` returns `SPHERE_NOT_FOUND`.
   - Required action: register/deploy the sphere through the authoritative Gopher workflow.
