# SIP observability — dev7

The communications stack treats observability as part of correctness, not as optional
console diagnostics. Core SIP objects emit structured `Directory` events through a
minimal `recordEvent(event)` sink contract. `SipAlchemyLogSink` adapts that contract to
the shared ooRexx Logging Framework v0.7.

## Wire events

Every UDP SIP datagram received or sent through `SipUdpTransport` emits `SIP.WIRE.RX`
or `SIP.WIRE.TX`, including local/peer endpoint, byte count and wire text. Socket send
or receive failures emit `SIP.WIRE.ERROR`.

## Registrar/authentication events

The registrar emits `SIP.AUTH.CHALLENGE` for an unauthenticated challenge,
`SIP.AUTH.REJECTED` when an Authorization-bearing REGISTER is challenged again,
`SIP.AUTH.ACCEPTED` when an Authorization-bearing REGISTER succeeds,
`SIP.REGISTRATION.BOUND` when a binding is created/refreshed, and
`SIP.REGISTRATION.REMOVED` on explicit deregistration.

This distinction is deliberate: a trace that repeatedly says only "challenge" is not
sufficient evidence for communications qualification. The structured trace records
whether an authenticated retry was actually present.

## Independent object events

Control, RTP receive, RTP send, inbound audio and outbound audio emit their own lifecycle
and failure records. Their `objectId` values remain distinct. Where an object belongs to
a SIP call, `callId` is present only as a correlation field.

Key families include:

- `SIP.CONTROL.*`
- `SIP.RTP.RX.*`
- `SIP.RTP.TX.*`
- `SIP.AUDIO.IN.*`
- `SIP.AUDIO.OUT.*`
- `SIP.CALL.*`

The log therefore reconstructs a call without making the call a monolithic owner.

## Logging-framework dependency

The production adapter expects the shared `LoggingCore.cls` API from ooRexx Logging
Framework v0.7. The framework and its targets/rules remain external. The tiny
`tests/logging_stub/LoggingCore.cls` is qualification scaffolding only and must not be
used in deployment.

## dev8 forensic ordering and registrar inspection

Every event emitted by `SipLogEmitter` carries three evidence fields in addition to
`schema`, `eventType`, `component` and `objectId`:

- `eventId` — random event identity;
- `eventSequence` — monotonically increasing sequence local to the emitting object;
- `emittedAtMs` — wall-clock Unix epoch milliseconds from the native boundary.

The sequence is deliberately local to each object. A single global call sequence would
quietly recreate the monolithic-call assumption that this package is designed to avoid.
Alchemy/ooRexx Logging is responsible for collecting the independent streams; common
correlation fields reconstruct a call or registration when needed.

REGISTER authentication rejection events now carry `reason`. Current reasons include
`missing-authorization`, `unsupported-algorithm`, `algorithm-mismatch`,
`username-mismatch`, `realm-mismatch`, `nonce-mismatch`, `uri-mismatch`,
`qop-mismatch`, `qop-fields-missing`, `response-missing`, and `response-mismatch`.
This means a repeated 401 can be diagnosed from the structured trace without guessing
whether the phone failed to send credentials or the supplied credentials were rejected.

Registrar state is independently inspectable through `SipRegistrationBinding` objects.
`SIP.REGISTRATION.BOUND`, `SIP.REGISTRATION.REFRESHED`,
`SIP.REGISTRATION.REMOVED`, and `SIP.REGISTRATION.EXPIRED` include the binding object
identity. Refresh preserves that identity and increments its revision.
