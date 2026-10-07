# Standards profile

The coverage request entered the grid as RFC 3920 / RFC 3921.  Those documents
are retained as historical provenance, but the implementation profile uses
their current successors.

| Concern | Spiral 1 profile |
|---|---|
| XMPP core streams, security, auth, stanza primitives | RFC 6120 (obsoletes RFC 3920) |
| Basic instant messaging and presence | RFC 6121 (obsoletes RFC 3921) |
| XMPP address format | RFC 7622, as updated by RFC 9844 |

The semantic public contract is **Messaging & Presence**.  The standards above
apply only inside the XMPP provider/session implementation.

## Included protocol semantics

- ordinary one-to-one message stanza projection
- basic availability/presence projection
- presence subscribe/unsubscribe projection
- provider-private address projection

## Explicitly excluded from core

- Multi-User Chat / chat-room products
- Publish-Subscribe
- file transfer
- avatars
- social contact-list product features
- extension-specific federation policy

Those are optional extension/plugin concerns and are not needed to demonstrate
Spiral 1 Messaging & Presence coverage.
