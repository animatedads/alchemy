# Architecture — dev8

## 1. IMAP is not IMAPS

There is one application protocol engine: IMAP. TLS placement is transport policy.

```text
ImapEndpoint
  host
  port
  security = PLAINTEXT | STARTTLS_REQUIRED | IMPLICIT_TLS
        |
ImapSocketTransport / future general NetStream
        |
ImapWireReader
        |
ImapSession
        |
capability-driven typed wrappers + generic command surface
```

`IMAPS` is not a second protocol implementation; it is the common name for IMAP carried over implicit TLS.

## 2. Security transition

Implicit TLS:

```text
TCP -> TLS handshake -> IMAP greeting -> CAPABILITY -> AUTH
```

Mandatory STARTTLS:

```text
TCP -> IMAP greeting -> use greeting CAPABILITY when present
    -> otherwise CAPABILITY
    -> STARTTLS
    -> TLS handshake on the same socket
    -> CAPABILITY again
    -> AUTH
```

Capabilities are snapshots at protocol boundaries. Pre-TLS or pre-auth capabilities must not be unioned indefinitely with later snapshots.

## 3. Large-mailbox invariants

Mailbox opening must depend primarily on visible window and changed state, not on total cardinality or unread cardinality. No API requires one ooRexx object per UID merely to retain a UID range or unread count.

Response literals are streamed, bounded and independently sinkable. Storage Fabric is the natural optional sink for large raw messages/attachments.

## 4. Protocol completeness

Typed wrappers are safety/convenience APIs, not a whitelist. `command()` remains available for standards-compliant extensions so broad servers such as Citadel can expose their complete IMAP surface.

## 5. Durable identity

Sequence numbers never belong in persistent state. Durable catalogue/migration identity is anchored by account/mailbox identity, `UIDVALIDITY`, and UID.

## 6. Protocol operation versus server semantics (dev5)

APPEND is an IMAP protocol operation, not a universal promise of passive storage.
The protocol engine remains server-neutral; `ImapSemantics.cls` carries explicit
behaviour profiles and mutation intent above it.

```text
caller intent: STORE | RESTORE | MIGRATE | POST | SUBMIT
        |
server behaviour profile
        |
semantic decision
        |
raw IMAP APPEND only when the declared effect matches
```

This preserves both ordinary passive mailbox operation and room-oriented systems such
as Citadel without hard-coding one server's meaning into `ImapSession` parsing.

## Dev6 write-path qualification boundary

IMAP is modelled as a bidirectional remote mailbox protocol, not a POP-like
download mechanism. The wire layer exposes APPEND and mailbox mutation directly;
`ImapSemantics.cls` remains above it to distinguish STORE/RESTORE/MIGRATE from
POST/SUBMIT effects. UIDPLUS APPENDUID is parsed as authoritative destination
identity when present. Absence of APPENDUID is not treated as failure and does not
justify guessing an identifier.

The live round-trip probe intentionally creates a fresh ordinary mailbox and
retains it after verification. Provider-specific cleanup is outside the generic
round-trip invariant.


## 7. Storage projection and search authority (dev7)

The filesystem view is not the mailbox authority and the search database is not the
mailbox authority.

```text
IMAP server authority
    |  UIDVALIDITY + UID
    v
IMAP catalogue projection --------> NoSQLServer v0.79 derived index
    |                                |  metadata + inverted terms
    |                                |  resumable index checkpoint
    v                                v
StorageRef ----------------------> bounded query result
    |
    v
Storage Fabric namespace/FUSE view
```

`StorageRef` identity never contains the friendly filename. Renaming a projection can
therefore change presentation without changing mail identity.

NoSQLServer is used for the persistent derived index because it already owns durable
file relations, query execution, crash-aware publication, adaptive value indexes and
index/journal reconciliation. IMAP does not reproduce those facilities.

A message index replacement uses a small fail-closed state machine:

```text
COMPLETE(old)
   -> BUILDING
   -> remove old terms
   -> insert replacement terms
   -> COMPLETE(new)
```

Search ignores BUILDING rows. A failed rebuild can therefore reduce search coverage
until repaired, but cannot turn partial index data into mailbox truth.

Body coverage is explicit. Header metadata may be indexed immediately while body text
remains remote. Search results expose whether all returned candidates had body text
indexed, avoiding the common mistake of presenting a partial local index as an
exhaustive remote search.

## 9. Transfer state machine (dev8)

Same-server relocation is capability-driven and fail-closed:

```text
selected source mailbox (READ-WRITE)
        |
        +-- MOVE available ----------------> UID MOVE
        |
        +-- no MOVE, UIDPLUS available ----> UID COPY
                                             UID STORE +\Deleted
                                             UID EXPUNGE exact UID set
        |
        +-- neither -----------------------> BLOCK
              unless caller explicitly accepts MARK_DELETED_ONLY / pending expunge
```

The implementation never turns absence of UIDPLUS into plain `EXPUNGE`; global
expunge has mailbox-wide side effects and is not an equivalent operation.

Cross-server/account transfer is a two-phase protocol:

```text
PREPARE/COPY
  fetch source metadata
  stream/read source with BODY.PEEK[]
  APPEND destination preserving safe flags + INTERNALDATE
  verify destination

COMMIT
  mark exact source UID(s) \Deleted
  UID EXPUNGE exact UID(s) when UIDPLUS exists
```

The IMAP library owns protocol correctness and source-removal safety. Storage Fabric
owns namespace projection, caching, filesystem verbs, and any later punchcard/MVS
representation. No punchcard or MVS logic belongs in this package.
