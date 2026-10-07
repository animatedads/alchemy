# ooRexx Messaging & Presence v0.1-dev1

Spiral 1 standards/COTS coverage slice for **Messaging & Presence**.

The public application model is deliberately not XMPP:

```text
application / agent / Intention
        |
        v
Messaging      Presence
        \        /
         provider registry   <--- fresh discovery every turn
                |
                +-- XMPP provider
                +-- future provider
```

XMPP is the first standards-backed provider.  It is not the service name and
JIDs/stanzas do not escape into application or Intention objects.

## Public objects

- `MessagingAddress`
- `Message`
- `MessagingDeliveryResult`
- `PresenceState`
- `PresenceSubscription`
- `Messaging`
- `Presence`
- `MessagingPresenceProviderRegistry`
- `MessagingPresenceProvider` / current provider offers

Objects are carried whole.  A provider receives the actual `Message`,
`MessagingAddress`, `PresenceState` and metadata objects.  Flattening is a
provider projection concern, never the application model.

## Dynamic capability truth

`MessagingPresenceProviderRegistry~discover()` calls every registered provider
each time.  A provider advertises a fresh `MessagingPresenceOffer` describing
what it can do **now**.  If a provider disappears or loses a capability, the
next discovery turn removes that operation without restart.

This is also how the Intention adapter works.  It publishes one transient
`IntentionSurfaceAdvertisement` only while the current provider set has useful
capability.  Natural language proposals come from that live surface, not from
permanent aliases in the Intention catalogue.

## XMPP provider

`providers/xmpp/XmppMessagingPresenceProvider.cls` projects semantic objects to
basic XMPP message and presence stanzas.  A standards-qualified `XmppSession`
implementation owns RFC 6120 stream setup, TLS/SASL, resource binding, XML
framing and parsing.

`XmppSocketTransport` gives such a session engine an isolated stream acquired
only through `SocketProvider~streamSender(logicalName)`.  It never creates a
raw socket itself.

The included ASCII address codec is a deliberately conservative qualification
profile.  It fails closed outside its subset rather than pretending to
implement the complete Unicode/PRECIS rules.  A live provider should register a
qualified RFC 7622 address codec/session engine.

## Deliberate non-features

This package does **not** implement MUC/chat rooms, PubSub, file transfer,
avatars, social contact-list UI, or a federation policy framework.  They are not
part of the Messaging & Presence access contract.  If an application needs an
XMPP extension, it belongs in a separately registered plugin/provider layer.

## Qualification

Run `tools/run_environment_test.sh` with current Socket Provider and Intention
Service source paths.  The script exercises semantic object preservation,
provider discovery, access classes, XMPP projection, socket isolation and
live Intention surface removal.

No live-XMPP interoperability claim is made by dev1 because no RFC 6120 session
engine is bundled.  That is an explicit qualification boundary, not a hidden
stub.
