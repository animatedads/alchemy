# Missing work — Messaging & Presence / XMPP / BOSH

Checked 2026-10-24.

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

5. **Concrete HTTP/HTTPS exchange authority for BOSH**
   - Existing HTTPS-over-XTP evidence is a composition witness using an injected fake HTTP provider.
   - No authoritative first-class generic HTTP client surface was identified in the current repository review.
   - Required action: bind BOSH to an existing exact HTTP client contract when one is identified, or create that platform contract in its owning workstream. BOSH itself must remain HTTP-implementation- and XTP-unaware.

6. **Sphere registration**
   - GitHub sphere content exists.
   - Current LLM Gopher `sphere_check` returns `SPHERE_NOT_FOUND`.
   - Required action: register/deploy the sphere through the authoritative Gopher workflow.
