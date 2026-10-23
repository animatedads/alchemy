# Spiral 1 COTS interface coverage — Messaging & Presence

| Field | Coverage |
|---|---|
| Semantic service | Messaging & Presence |
| Public service APIs | `messaging/0.1`, `presence/0.1` |
| Provider contract | `messaging.presence.provider/0.1` |
| Intention surface | dynamic capability-derived discovery and semantic dispatch |
| First standards provider | XMPP |
| Historical provenance | RFC 3920, RFC 3921 |
| Current core profile | RFC 6120, RFC 6121 |
| Address profile | RFC 7622 as subsequently updated |
| Authentication | SASL PLAIN only after protected transport |
| Socket ownership | lower SocketProvider/selector only |
| Extension policy | separate registered semantic plugins |
| Transcript qualification | PASS |
| Live RFC 6120 server qualification | recorded lower STARTTLS boundary |

Qualified path: natural request/application/agent → dynamic Intention surface → Messaging/Presence → current provider offer → XMPP provider → XmppSessionEngine → lower stream/selector.

Evidence includes complete semantic object retention, message/presence stanza projection, incremental XMPP framing, STARTTLS/SASL/bind transcript progression, downgrade refusal, inbound semantic projection, and absence of extension-specific operations from the core.

Operational instrumentation uses the common `instrumentation.mesh/0.1` contract. Observation does not grant Messaging/Presence mutation authority.
