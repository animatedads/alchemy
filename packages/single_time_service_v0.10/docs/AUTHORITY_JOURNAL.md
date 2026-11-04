# Temporal authority journal v0.6

`TimeAuthorityLedger.cls` uses an append-only, line-oriented local file.
Every record has `STS6|sequence|previousChecksum|OP|n|hexFields...|checksum|COMMIT`.
Fields use ASCII hex of the ooRexx string bytes to safely encode newlines and
separators. All commands are validated by constructing candidate state before
append. Invalid commands never advance the ledger.

Recovery processes every entry in order and rejects malformed records,
nonmonotonic sequences, bad previous links, checksums, and invalid domain
mutations. It will **not** silently discard a damaged tail. An operator may
restore an independently verified backup to a new path.

Supported commands: `CALENDAR`, `EVENT`, `CLOSE`, `CANCEL`, `MOVE`, `BIND`,
`UNBIND`. A journal has maximum 100,000 records; individual serialized lines
are limited to 65,536 characters, and each field is limited to 8,192 chars.
This intentionally favors small and auditable management histories. Each write
replays full current history for validation and conflict checks; not suited for
high-throughput event telemetry.

### Authority and security

The management API is trusted local code. Put journal paths in an access-controlled
directory and prevent untrusted processes from modifying or replacing them.
The checksum is deliberately **not cryptographic**; it is for accidental
corruption only and cannot establish authorship, trusted clocks, or tamper
resistance. `OPEN WRITE APPEND` and `CLOSE` are not atomic transaction/fsync
guarantees. Never have multiple processes write one journal: the read-before-
write conflict guard is helpful but not a distributed or process-safe lock.

`resolveAt()` reconstructs event/calendar *definitions* at a revision, then
uses the explicitly injected `timeService` rule provider. Freeze the original
TZif data and retain original result envelopes separately if a later rule
change must not rewrite historic UTC projections. Recorded journal revisions
are not time-based snapshots (no trusted `createdAt` field).

The service makes no claims of Queue Fabric scheduling or exactly-once job
execution. Event publication, subscribers, clock sources, authority signatures,
fsync durability, cross-process locking, and rule-edition snapshot replay
remain separate subsequent concerns.
