# Standards profile

The coverage request entered the grid as RFC 3920 / RFC 3921. Those documents remain historical provenance, while implementation uses their successors.

| Concern | Spiral 1 profile |
|---|---|
| XMPP core streams, STARTTLS, SASL negotiation, resource binding and stanza primitives | RFC 6120 |
| Basic instant messaging and presence | RFC 6121 |
| XMPP address format | RFC 7622, as subsequently updated |
| SASL PLAIN mechanism payload | RFC 4616 |

The semantic public contract is **Messaging & Presence**. These standards apply only inside the XMPP provider/session implementation.

Core includes ordinary one-to-one message projection/parsing, basic availability/presence, subscribe/unsubscribe, provider-private address projection, incremental framing, STARTTLS state and downgrade refusal, protected-only SASL PLAIN, post-authentication stream restart and resource binding.

Explicitly excluded from core: Multi-User Chat/chat-room products, Publish-Subscribe, file transfer, avatars, social contact-list product features, and extension-specific federation policy. Those are optional registered semantic plugin services.
