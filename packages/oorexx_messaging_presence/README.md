# ooRexx Messaging & Presence v0.1-dev4

Spiral 1 standards/COTS coverage slice for **Messaging & Presence**.

The application-facing service is deliberately not named after its first wire protocol. XMPP is a standards-backed provider. JIDs, stanzas and XMPP extension names do not escape into the application or Intention model.

## Public semantic objects

- `MessagingAddress`
- `Message`
- `MessagingDeliveryResult`
- `PresenceState`
- `PresenceSubscription`
- `Messaging`
- `Presence`
- `MessagingPresenceProviderRegistry`
- `MessagingPresenceProvider` / current `MessagingPresenceOffer` objects

Objects are carried whole. A provider receives the exact `Message`, `MessagingAddress`, `PresenceState`, metadata and context objects. Flattening is a provider projection concern only.

## Executable Intention route

`MessagingPresenceIntentions.cls` provides dynamic discovery and dispatch. The Intention layer produces semantic plans and slots. At dispatch it resolves a human/application identity through `MessagingPresenceAddressResolver`, creates full `Message` or `PresenceState` objects, and invokes the `Messaging` or `Presence` access class. It never chooses XMPP, a JID, TCP, TLS or a socket.

The surface remains dynamic. If currently discovered providers lose a capability, that meaning disappears on the next discovery refresh rather than remaining as a stale static command.

## Registered extension boundary

`MessagingPresenceExtensions.cls` is the executable plugin boundary for things that are not core Messaging or Presence. A plugin registers a **semantic service of its own** and may provide its own dynamic Intention discovery provider.

This is intentionally not an XMPP-XEP catalogue. Installing a plugin does not add methods or capabilities to `Messaging` or `Presence` merely because XMPP has a corresponding extension.

Facilities such as group conversation, event publication, file exchange, avatar/profile media, or other optional features therefore remain separate registered services rather than turning the core into a chat platform.

## XMPP provider and session engine

`providers/xmpp/XmppMessagingPresenceProvider.cls` projects semantic objects to basic RFC 6120/6121 message and presence stanzas.

`providers/xmpp/XmppSessionEngine.cls` supplies provider-private session mechanics: incremental framing of the open-ended XMPP XML stream; stream restart after security/authentication transitions; STARTTLS negotiation state and downgrade refusal; SASL PLAIN after transport protection; resource binding; inbound ordinary message parsing; inbound availability/presence parsing and cache; and provider-private events projected back into semantic objects.

`XmppSocketTransport` acquires its byte stream only through `SocketProvider~streamSender(logicalName)` and never creates, selects or wraps a native socket itself.

### Current live-interoperability boundary

Socket Provider v0.1-dev14 models TLS as a separately acquired secure socket family but does not expose an in-place TLS upgrade of an already-open TCP stream. Standard XMPP STARTTLS requires that same-stream transition. dev4 therefore **fails closed** rather than bypassing SocketProvider or sending SASL credentials over an unprotected connection.

See `SOCKET_PROVIDER_STARTTLS_REQUIREMENT.md`. Live RFC 6120 server interoperability through that older qualification baseline is not claimed.

The included ASCII address codec remains deliberately conservative. It fails closed outside its stated subset rather than pretending to implement the complete Unicode/PRECIS/IDNA requirements.

## Standards provenance

Historical RFC 3920 / RFC 3921 remain provenance. Their implementation successors are RFC 6120 and RFC 6121. RFC 7622, as subsequently updated, supplies the XMPP address-format boundary. SASL PLAIN follows RFC 4616.

## Instrumentation Mesh integration

`src/MessagingPresenceInstrumentation.cls` is the optional adapter for `instrumentation.mesh/0.1`. Messaging & Presence does not create a local metrics/history protocol: authoritative service facts are emitted through the common Instrumentation emitter and common publication/collector path.

Observation does not grant message/presence mutation authority.
