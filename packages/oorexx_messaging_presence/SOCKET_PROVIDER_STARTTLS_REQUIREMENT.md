# Socket Provider requirement: in-place TLS upgrade

`XmppSessionEngine` implements RFC 6120 STARTTLS state, but the dev14 Socket Provider qualification baseline exposes TLS as a separately acquired socket family and not an in-place upgrade of an already-open TCP stream.

Standard XMPP STARTTLS requires the TLS handshake on the same byte stream after initial XMPP features. Messaging & Presence therefore fails closed: it does not send SASL credentials on an unprotected connection and does not bypass SocketProvider with a native socket workaround.

A lower provider should own an operation semantically equivalent to upgrading an existing provider-owned stream to TLS while preserving connection identity, security-profile/trust resolution and native-handle ownership.

Once that capability exists, `XmppSocketTransport~supportsStartTls` / `~startTls` can delegate without changing Messaging, Presence, Intention or XMPP provider contracts.

Qualified already: incremental framing, STARTTLS protocol state/downgrade refusal, protected-only SASL PLAIN, stream restart, resource binding, inbound message/presence parsing and semantic projection.

Live RFC 6120 client-to-server interoperability is not claimed against the dev14 qualification baseline until the lower provider exposes and qualifies same-stream STARTTLS.
