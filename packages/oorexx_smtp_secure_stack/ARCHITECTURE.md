# Architecture

## Authority separation

SMTP is a protocol/service edge, not an identity or authorization authority.

`transport TLS -> authentication attribution -> message signature verification -> EMAIL_SEND authority -> deterministic/model egress policy -> relay queue`

For inbound local delivery:

`transport -> signature verification/evidence -> ingress deterministic/model policy -> INBOX or INBOX-UNSIGNED -> durable delivery`

A message signature never substitutes for `EMAIL_SEND` authorization. Authentication never substitutes for either.

## Core objects

- `SmtpSession` — association identity/TLS state.
- `SmtpEnvelope` / `SmtpMessage` — envelope, raw content and policy metadata.
- `SmtpMessageSignatureVerifier` — verifies the signature already carried by a message.
- `SmtpMessageSignatureEvidence` — present/verified/signer/certificate/profile evidence.
- `SmtpAccessAuthority` — protected action authority; relay asks for `EMAIL_SEND` on `SMTP:RELAY`.
- `SmtpPolicyInspector` — deterministic ingress/egress inspection.
- `SmtpModelAdvisor` — ML/LLM classification/advice.
- `SmtpDeliveryProvider` — local mailbox, quarantine and signed-relay boundary.
- `SmtpEventSink` — observation/audit projection.

## Message signature handling

Outbound relay uses **verification, not automatic signing**. A user or trusted composing agent must sign the message before submission. The verifier must bind the valid signature to the same principal attributed to the SMTP session.

Inbound routing treats only a cryptographically verified signature as signed. A syntactically present but invalid signature is routed as unsigned (`INBOX-UNSIGNED`) unless a policy inspector chooses a stronger action such as quarantine/reject.

## Anti-spam / ML / LLM

Model integration is intentionally behind `SmtpModelAdvisor` so model revisions/providers cannot silently become the authorization system. Advisors may produce scores/reasons/evidence and recommend allow/quarantine/reject/defer. Deterministic policy interprets those outputs.

Suggested providers can cover:

- classical spam probability / Bayesian or learned classification;
- URL/domain reputation;
- sender/IP/domain behavioural reputation;
- phishing, impersonation and credential-theft cues;
- attachment/MIME anomaly classifiers;
- outbound anomaly and recipient fan-out detection;
- LLM semantic abuse/social-engineering explanation;
- graph or historical-contact consistency signals.

Ingress and egress have independent configuration and can require different providers/thresholds.

## Secure socket

`secure.socket/0.1` is protocol-neutral. Server/client OpenSSL implementations retain the LDAP dev10 Foreign Runtime bridge strategy, including TLS 1.2 minimum configuration, peer verification on the client side, SNI and hostname verification, and memory BIO transport.

This permits LDAP, SMTP and later protocol servers to converge on one TLS substrate rather than carrying protocol-specific clones.

## dev3 concrete authority bindings

- `AccessPermissionsSmtpAuthorityV1` creates the same Access Permissions request/envelope shape used by LDAP dev10 and asks for `EMAIL_SEND` independently of authentication/signature proof.
- `OpenSslSmimeMessageSignatureVerifier` verifies S/MIME/CMS with OpenSSL, projects signer email identity and certificate SHA-256 fingerprint, and refuses identity mismatch for relay.
- Signature evidence is written into `SmtpMessage~metadata` before ingress/egress policy and model inspection. Policy/model action, reason and score are then projected into the same metadata and event stream.
- DKIM alone is not treated as a user message signature. Unsupported PGP/MIME is recognised as signature-present-but-unverified until a PGP provider is configured.

## dev4 durable delivery boundary

Message bytes are immutable durable objects. Mailbox membership (`INBOX`, `INBOX-UNSIGNED`), quarantine and outbound spool are projections that reference the same object. Storage Fabric remains storage/catalogue authority; SMTP owns only mail-specific projection semantics.

Outbound sequence is: authenticated principal -> verify message signature/identity -> `EMAIL_SEND` authority -> egress deterministic/model inspection -> durable Storage Fabric object -> durable spool projection -> persistent QueueRexx/Queue Fabric request. A downstream dispatcher must revalidate the egress policy before network release; queue presence by itself is never release authority.

Queue messages carry references, not a second authoritative message body. This prevents queue retry/replay from silently forking mail content or signature evidence.

## dev5 outbound release and dispatch

`SmtpOutboundDispatcher` is the release boundary between durable spool state and the network.
It reloads the single Storage Fabric message object, reconstructs the attributed principal,
and calls `SmtpService~validateRelayRelease()` immediately before any next-hop connection.
That operation re-verifies the message signature, re-asks `EMAIL_SEND`, and re-runs egress
policy/model inspection. A prior queue-time permit is deliberately not reusable authority.

Recipient delivery state is journaled independently. A recipient already accepted by a
remote server is not retransmitted when another recipient defers. Temporary failures remain
DEFERRED; permanent failures produce FAILED recipient state plus durable bounce evidence.

The default concrete transport is `RxSockStartTlsSmtpRelayTransport`. STARTTLS is mandatory
unless an explicitly different hop policy is constructed. The OpenSSL secure-socket client
performs CA validation, hostname binding/SNI, TLS handshake and encrypted SMTP I/O.

## dev7 platform socket boundary

Socket Provider v0.1-dev13 is the native endpoint acquisition authority.  When supplied,
`SmtpPlatformSocketConnector` constructs the resolved TCP `SocketAddress` and calls
`SocketProvider~senderAt()`.  SMTP keeps ownership of SMTP command ordering and STARTTLS timing;
it does not ask Socket Provider to guess when an already-open SMTP stream should be upgraded.
The OpenSSL secure-socket provider therefore upgrades the raw stream only after the peer's
successful STARTTLS response.

The legacy direct RxSock connector remains a compatibility fallback, not the preferred estate
composition path.

## dev7 MAS/MAIL authority boundary

MAS/MAIL is an application personality above SMTP, not a source of cryptographic or access
truth.  Guest assertions are never promoted into signature or `EMAIL_SEND` authority.  Host
principal attribution is mandatory, and the exact same `SmtpService~relayOutbound()` path used
by ordinary SMTP submission is used for MAS release.
