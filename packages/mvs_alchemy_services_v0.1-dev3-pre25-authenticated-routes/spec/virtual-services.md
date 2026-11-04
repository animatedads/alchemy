# MAS virtual host services — dev3-pre6

MVS Alchemy Services presents stable MVS-facing personalities while the implementation lives on the Hercules host.  The guest therefore does not need native Queue Fabric, database, IMAP or SMTP protocol implementations.

## Delivered provider boundary

`host/reference/virtual_services_reference.py` defines four replaceable host providers:

- `QueueProvider` — opaque-byte FIFO queues.  Qualification provider: `MemoryQueueProvider`.
- `DatabaseProvider` — opaque-byte key/value object service with bounded ordered scans.  Qualification provider: `MemoryDatabaseProvider`.
- `ImapProvider` — mailbox catalogue, UIDVALIDITY+UID lookup and seen-state mutation.  Qualification provider: `MemoryImapProvider`.
- `SmtpProvider` — outbound submission after the existing MAS signature, identity, EMAIL_SEND and egress gates.  Qualification provider: `MemorySmtpProvider`.

`MasVirtualServices` composes the four providers.  The MVS ABI binds to this semantic layer, never to provider-native class names.

## Deployment bindings

The qualification providers prove the MVS-side semantics without requiring a network service.  Production adapters are expected to bind:

- Queue -> Queue Fabric / QueueRexx.
- Database -> NoSQLServer v0.87 DB2/generic database service boundary; MAS does not own DB2 parsing/result semantics.
- IMAP -> `imap/0.1` server/service API (current reviewed line: ooRexx IMAP v0.1-dev12).
- SMTP -> secure SMTP stack (current reviewed line: ooRexx SMTP Secure Stack v0.1-dev8).

The production packages remain independent authorities.  MAS does not pretend that an in-memory qualification provider is the production protocol implementation.

## Opaque data rule

Queue payloads, database keys/values, message bodies, MIME parts and attachments are `BYTES`.  No EBCDIC/ASCII translation is permitted merely because the caller is MVS.

## Database personality

The earlier personality reservation `1100-11FF` is now backed by executable host semantics rather than a reservation only.  Initial operations are:

- DBOPEN `1100`
- DBGET `1101`
- DBPUT `1102`
- DBDELETE `1103`
- DBSCAN `1104`
- DBCLOSE `1105`

This is an MVS compatibility personality, not a claim to reproduce IBM DB2.
