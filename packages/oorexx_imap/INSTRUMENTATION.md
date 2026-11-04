# IMAP Instrumentation Mesh integration — dev13

`ImapInstrumentationAdapter.cls` is the optional observation bridge from the
Rexx-space IMAP server into `instrumentation.mesh/0.1`. It does not own
publication cadence, history, transport, authentication, mailbox policy or
management authority.

## Source lifetime

Create one `ImapInstrumentationSource` for one resident IMAP service instance
and share it across that instance's accepted sessions. Register the source in an
`InstrumentationRegistry` when Mesh publication/query is required.

```rexx
identity = .InstrumentationCodec~identity( -
    "estate-a", "imap", "imap-1", "node-a", "", "IMAP")
metrics = .ImapInstrumentationSource~new(identity)
endpoint = .ImapServerEndpoint~new(session, 100000, 1048576, metrics)
```

The endpoint observer contract is dependency-neutral, so the IMAP server can run
without Instrumentation Mesh installed.

## Emitted facts

The adapter uses the Mesh generic request and byte vocabulary and adds IMAP
service metrics:

- `request.accepted.total`, `request.completed.total`, `request.failed.total`,
  `request.inflight`;
- `io.bytes.in.total`, `io.bytes.out.total`;
- `imap.sessions.accepted.total`, `imap.sessions.closed.total`,
  `imap.sessions.active`, `imap.sessions.authenticated`,
  `imap.sessions.selected`;
- TLS/plaintext accepted-session counters;
- authentication attempt/success/failure counters;
- `imap.command.<safe-command>.accepted.total` plus terminal
  `.completed.total`, `.ok.total`, `.no.total`, `.bad.total` and `.failed.total`;
- `imap.literal.bytes.in.total`;
- `imap.transport.failures.total`.

UID commands are represented by their bounded semantic command name such as
`uid_fetch` or `uid_move`; command arguments are never dimensions.

## Privacy boundary

Telemetry must not contain usernames/principal ids, credentials, mailbox names,
raw commands, SEARCH expressions, message headers/bodies, literal bytes, secret
references, bearer tokens, capability URLs or private provider handles. The
adapter receives only safe command names, terminal protocol status, state names
and byte counts.

## Authority boundary

Instrumentation is observational. A collector, publisher, dashboard or NOC has
no right to select a mailbox, close a session, move mail or expunge a message.
A future remote management operation must pass both the Instrumentation command
authorizer and an explicit IMAP-local authority surface. Projection mutation is
never operational authority.

## Dev13 IDLE and socket-isolation layering

The IMAP Instrumentation Mesh adapter adds:

* `imap.idle.started.total`
* `imap.idle.stopped.total`
* `imap.idle.active`
* `imap.idle.updates.total`
* `imap.idle.events.total`

A single `IDLE` command remains one Mesh request: admission occurs before the
continuation response and completion occurs only after `DONE` (or terminal
failure).  Unsolicited mailbox updates increment update/event counters but do not
create synthetic client commands.

The Library's `socket.telemetry/0.1` decorator is a lower-layer complement, not a
replacement.  It can observe Socket Provider acquisition, accept, read/write call
counts, byte totals, active gauges and close while the IMAP adapter records semantic
command/session facts.  Default socket telemetry excludes payloads, peer/host
identity, logical service names, Unix paths, security profiles and canonical/native
endpoint identity.  IMAP does not copy those generic socket counters into its own
namespace.

