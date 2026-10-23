# ooRexx Messaging & Presence Gopher Sphere v0.1

Authoritative engineering sphere for the semantic Messaging & Presence library and its standards-backed XMPP provider family.

The public service is **Messaging and Presence**, not XMPP. XMPP is a provider behind semantic access classes. XEP-0206 is a separate XMPP-over-BOSH binding. BOSH is a separate lower-layer logical stream transport and may be carried by HTTP(S) over any conforming lower selector path, including XTP.

Core invariants:

- applications and intentions consume `Message`, `MessagingAddress`, `PresenceState` and semantic provider capabilities, not JIDs or XMPP stanzas;
- full ooRexx objects remain intact through access-class and intention dispatch;
- provider/intention discovery is dynamic and capability-based;
- MUC/chat rooms, PubSub, file transfer, avatars and federation-policy frameworks are not core Messaging/Presence semantics and require separately registered plugin services if desired;
- XMPP does not own sockets; it requests a suitable stream from the lower provider/selector boundary;
- BOSH is not an XMPP feature in the public model and does not depend on XMPP, TLS, SocketProvider or XTP;
- XEP-0206 is the narrow adapter that knows both XMPP and BOSH;
- Instrumentation Mesh is observation only. Correlation/causation is explicit and never inferred from timing, topology, payload or co-location.

## Current implementation baselines

- Messaging & Presence: `oorexx_messaging_presence_v0.1-dev4.zip`
  - SHA-256 `6910c88cc209ff24117461761a0eecf98272f68c98ae17a6686db932afb3742f`
- BOSH transport: `oorexx_bosh_transport_v0.1-dev5.zip`
  - SHA-256 `072555ee2fd1ac8d02ede22d280015d0904b2db805a05d49a51c5e2c0eeebd67`
- XMPP/BOSH adapter: `oorexx_xmpp_bosh_adapter_v0.1-dev2.zip`
  - SHA-256 `5101f283dab036c18574ae90d03480ecc634c90d4e478f1458fac0481943525b`
- Instrumentation baseline reviewed in Library: `oorexx_instrumentation_mesh_v0.1-dev8.zip`
- Current transport-grid baseline reviewed in Library: `SPIRAL1_TRANSPORT_COTS_INTERFACE_GRID_CURRENT_2026-10-13.md`

Repository implementations live at `packages/oorexx_messaging_presence/`, `packages/oorexx_bosh_transport/`, and `packages/oorexx_xmpp_bosh_adapter/`. The sphere records architecture, authority and qualification continuity; it does not replace those runtime packages.
