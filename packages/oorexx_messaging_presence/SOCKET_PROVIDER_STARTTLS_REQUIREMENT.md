# Socket Provider requirement: in-place TLS upgrade

`XmppSessionEngine` implements RFC 6120 STARTTLS state. The current estate Socket Provider authority is **v0.1-dev16**, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

The current evidence reviewed for dev16 establishes the shared socket/provider isolation boundary, but does **not** establish a generic provider operation that upgrades an already-open stream in place to TLS. The first-class GitHub Socket Provider source tree still identifies as dev14, so this requirement must not be closed by inferring dev16 implementation from stale source.

Standard XMPP STARTTLS requires the TLS handshake on the same byte stream after initial XMPP features. Messaging & Presence therefore fails closed: it does not send SASL credentials on an unprotected connection and does not bypass SocketProvider with a native socket workaround.

A lower transport/TLS authority must provide an explicitly qualified operation semantically equivalent to upgrading an existing provider-owned stream while preserving connection identity, security-profile/trust resolution and native-handle ownership. SMTP and LDAP have protocol-specific secure-provider upgrade paths elsewhere in the estate; those are evidence that the operation is feasible, not proof that the generic SocketProvider contract currently exposes it.

Once a qualified lower seam exists, `XmppSocketTransport~supportsStartTls` / `~startTls` can delegate without changing Messaging, Presence, Intention or XMPP provider contracts.

Qualified already: incremental framing, STARTTLS protocol state/downgrade refusal, protected-only SASL PLAIN, stream restart, resource binding, inbound message/presence parsing and semantic projection.

Live RFC 6120 client-to-server interoperability is not claimed through the current shared-provider boundary until the same-stream STARTTLS route is explicitly supplied and qualified.
