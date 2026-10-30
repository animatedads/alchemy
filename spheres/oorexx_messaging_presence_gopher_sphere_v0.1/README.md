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


## 2026-10-24 reconciliation

The repository and Library have advanced beyond the original 2026-10-13 transport-grid snapshot.

Current externally evidenced context:

- Socket Provider v0.1-dev16 — SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.
- Network Transport Intentions v0.1-dev3 — SHA-256 `d90dc49e4799f929761e75b302ab141a3bab481efdf951cdd508491a9b18c64b`.
- Instrumentation Mesh v0.1-dev8 — SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`.
- XTP v0.1-dev25 development head — SHA-256 `7f6ab3d1167d5fd3131c7e6d6e9ea8d8c6115106ea9df89d41357ef56773b80b`.
- BOSH released evidence remains dev5; the GitHub source line is now dev6 to repair qualification/current-version metadata without changing the dev5 wire/session semantics.

Two source-publication boundaries are explicit. The first-class GitHub Socket Provider tree still identifies itself as dev14 even though current estate evidence pins dev16. The first-class Instrumentation Mesh dev8 runtime source is also not published under its own package tree. Neither implementation may be reconstructed or relabelled from older source merely to make a test green.

Messaging & Presence therefore continues to fail closed for RFC 6120 STARTTLS until a generic same-stream secure-upgrade route is explicitly qualified at the lower transport/TLS boundary. BOSH remains a generic HTTP-carried logical stream; a real generic HTTP/HTTPS exchange provider (including HTTPS-over-XTP composition) remains separate work because no authoritative first-class HTTP client surface was identified in the current repository review.

The sphere is present in GitHub and linked to the authenticated Rasen Falcon `messaging-presence` lane. The current Rasen Falcon deployment reports `SPHERE_CHECKER_UNAVAILABLE` because no sphere checker is configured; this is an infrastructure/configuration gate, not evidence that the sphere ID is absent.


## 2026-10-29 source integration

Two previously open lower-transport seams are now integrated on `main`:

- `oorexx_bosh_api_client_adapter` v0.1-dev1, squash merge `12077975acaa9610ad1c696a703ce9f698b928ad`, binds the generic BOSH HTTP exchange seam to API Client v0.4.1 while keeping BOSH free of XMPP, SocketProvider and XTP knowledge.
- `oorexx_api_client_socket_provider_adapter` v0.1-dev1 plus the optional `ApiSocketConnector` seam, squash merge `265aeaa86714cfc5c014b9b4cca136d9e6c9476d`, lets API Client acquire an exact selected SocketProvider stream while preserving RxSock as the default carrier.

The resulting authority chain is now:

```text
Messaging / XMPP
      |
     BOSH
      |
 API Client HTTP/HTTPS
      |
 API Client TLS
      |
 optional ApiSocketConnector
      |
 SocketProvider / selector
      |
 TCP / XTP / other qualified stream family
```

Selection still belongs below API Client. Neither BOSH nor API Client chooses XTP.

Current Git XTP development context reviewed is dev33. dev33 depends on Socket Provider dev16 and adds per-service protection for sessions, messages and streams, with LDAP Identity Directory plus Secret Broker as the optional key-source path. That is relevant to the estate's internode and own-LDAP requirements, but it does not make live HTTPS-over-XTP qualified automatically.

Runtime qualification of the two newly integrated seams under ooRexx r13196, followed by an exact XTP dev33 selected-stream HTTPS run, remains explicit work. Autobuilder is not assumed.
