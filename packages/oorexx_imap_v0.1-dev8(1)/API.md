# API — `imap/0.1` — dev8

## `ImapTransportSecurity`

Canonical values:

* `PLAINTEXT`
* `STARTTLS_REQUIRED`
* `IMPLICIT_TLS`

Class methods:

* `canonical(label)` — returns a canonical value or fails on unknown/ambiguous labels.
* `defaultPort(label)` — 993 for implicit TLS; 143 for STARTTLS/plaintext.
* `isEncryptedFromConnect(label)`
* `needsStartTls(label)`

Bare `IMAP`, `TLS`, `SSL`, `SSL/TLS`, `SECURE` are intentionally rejected as ambiguous.

## `ImapEndpoint`

Attributes:

* `host`
* `port` — `0` means derive conventional port after security canonicalization.
* `security`

Methods:

* `validate()`
* `encryptedFromConnect()`
* `requiresStartTls()`

The application protocol is always IMAP. `IMAPS` is treated only as a compatibility name for IMAP over `IMPLICIT_TLS`.

## `ImapSocketTransportConfig`

Attributes include `host`, `port`, `security`, `bridgeDirectory`, `caFile`, verification and timeout settings.

`mode` remains for dev1 source compatibility only. If both `security` and `mode` are supplied, they must canonicalize to the same value or validation fails.

`applyEndpoint(endpoint)` copies validated host/port/security values from `ImapEndpoint`.

## `ImapSession`

`ImapSession~new(transport [, readerConfig])`

Important dev2 operation:

* `bootstrapSecurity([security])` — accept greeting, enforce the explicit transport-security policy, perform mandatory STARTTLS when requested, and obtain a fresh post-boundary capability snapshot.

Existing operations:

* `acceptGreeting()`
* `capability()` — successful responses replace the capability snapshot.
* `startTls()`
* `login(user,password)` — refuses `LOGINDISABLED` and cleartext-password transport.
* `command(text [, literalSinkFactory])`
* `examine`, `select`, `status`
* `uidFetchPeek`, `uidFetchBodyPeek`
* `uidStore`, `uidCopy`, `uidMove`
* `uidSearch`
* `appendBytes`, `appendSource`
* `noop`, `logout`

## `ImapUidSet`

Range-based representation. `1:1000000` remains a single range. `toArray(limit)` must be requested explicitly and fails beyond the caller limit.

## `ImapWireReader`

Streaming CRLF/literal reader with explicit line, literal and response-record limits. Literal data larger than the inline threshold is consumed without retention unless a sink factory is supplied.

## `ImapMailboxState`

`unseenCount` is the count from `STATUS ... (UNSEEN)`.

`firstUnseenSequence` is the historical `[UNSEEN n]` response code from SELECT/EXAMINE and is **not** an unread count.


## Diagnostics / ooRexx Logging bridge (dev4)

```rexx
session = .ImapSession~new(transport [, readerConfig [, eventSink]])
session~setEventSink(eventSink)
lastError = session~lastEventError

adapter = .ImapLoggingAdapter~new(logService [, nativeScope])
```

Logging rules should target class `ImapSession`, method `EVENT`; the structured
IMAP event name is supplied as the LogEvent point.  The IMAP core has no hard
dependency on LoggingCore.cls.

## Semantic mutation planning (dev5)

`ImapSemantics.cls` adds an application-semantics layer above raw IMAP mutation:

* `ImapMailboxRole~canonical()` — `ORDINARY`, `SENT`, `DRAFTS`, `JUNK`, `TRASH`, `ARCHIVE`.
* `ImapMutationIntent~canonical()` — `STORE`, `RESTORE`, `MIGRATE`, `POST`, `SUBMIT`.
* `ImapServerBehaviorProfile~generic()` — ordinary APPEND is passive; special-use effects remain server-defined.
* `ImapServerBehaviorProfile~citadel()` — room APPEND is modelled as POST, Sent APPEND as SUBMIT, and SMTP is declared to record Sent automatically.
* `profile~planAppend(role,intent)` returns an `ImapMutationDecision`.
* `profile~shouldClientAppendSentAfterSmtp()` prevents duplicate Sent archival on servers that already record SMTP submissions.

`ImapSession` adds:

* `appendBytesWithIntent(mailbox, bytes, profile [, role [, intent [, flags [, internalDate [, sinkFactory]]]]])`
* `appendSourceWithIntent(mailbox, source, length, profile [, role [, intent [, flags [, internalDate [, sinkFactory]]]]])`

A semantic mismatch fails before the APPEND command is put on the wire.  The existing
raw `appendBytes()` and `appendSource()` methods remain unchanged and deliberately
represent protocol-level APPEND rather than policy.

## Bidirectional mailbox operations (dev6)

Typed mailbox operations now include:

* `createMailbox(mailbox)`
* `deleteMailbox(mailbox)`
* `renameMailbox(oldMailbox,newMailbox)`
* `subscribeMailbox(mailbox)`
* `unsubscribeMailbox(mailbox)`
* `closeMailbox()`

APPEND result helpers preserve existing raw APPEND methods and add UIDPLUS-aware
results:

* `appendBytesResult(...) -> ImapAppendResult`
* `appendSourceResult(...) -> ImapAppendResult`
* `appendBytesWithIntentResult(...) -> ImapAppendResult`
* `appendSourceWithIntentResult(...) -> ImapAppendResult`
* `parseAppendResult(commandResult)`

`ImapAppendResult` exposes `commandResult`, `ok`, `hasAppendUid`, `uidValidity`,
and compact `uidSet`. If the server does not return `[APPENDUID ...]`,
`hasAppendUid` is false and no UID is guessed.


## Dev7 index/search API

### `ImapIndexRecord`
Database-neutral UID-bound message metadata. `~key` is derived from account, mailbox,
UIDVALIDITY and UID; `~fromKey` normalizes an address for exact sender queries.

### `ImapIndexText`
`~tokens(text [, minLength [, maxLength [, maxUnique]]])` returns distinct bounded
search tokens. Email punctuation (`@._+-`) is retained so addresses such as
`no-reply@accounts.google.com` remain one token.

### `ImapNoSQLIndex`
Optional NoSQLServer v0.79 adapter:

* `~indexMessage(record [, bodyText])`
* `~removeMessage(messageKey)`
* `~searchFrom(address [, limit [, account [, mailbox]]])`
* `~searchText(query [, limit [, account [, mailbox]]])`
* `~checkpointMailbox(account, mailbox, uidValidity, ...)`
* `~mailboxCheckpoint(account, mailbox)`
* `~buildSearchIndexes()`

Search limits are bounded (1..10000). `searchText` uses AND semantics across query
terms. The returned `ImapIndexSearchResult` exposes `~truncated` and
`~bodyCoverageComplete`.

### Storage Fabric dev13 projection

`ImapStorageMessageRecord~storageObject(providerId)` creates the Storage object and
mail metadata EAs. `ImapStorageNamespaceProjector~bindMessage(s)` creates READ_ONLY
friendly names. `~bindIndexResult()` consumes database-neutral index results.
`ImapStorageRawByteSource` supplies bounded ranged message bytes using `BODY.PEEK[]`.
`ImapStorageSemanticSelector` parses the provider semantic selector tail without
claiming that every selector is already implemented by Storage Fabric.

## Dev8 transfer/move API

`ImapSession` adds explicit low-level message-removal helpers:

* `uidMarkDeleted(uidSet)` -> `UID STORE ... +FLAGS.SILENT (\Deleted)`
* `uidUnmarkDeleted(uidSet)`
* `uidExpunge(uidSet)` -> requires `UIDPLUS`; there is intentionally no hidden
  fallback to global `EXPUNGE`.

`ImapUidSet` adds non-materializing mapping helpers:

* `ordinalOf(uid)`
* `uidAtOrdinal(n)`

`ImapTransfer.cls` adds:

* `ImapTransferOps~parseCopyUid(commandResult)` -> `ImapCopyUidResult`
* `ImapTransferOps~planSameSessionMove(session [, allowPendingExpunge [, preferNative]])`
* `ImapTransferOps~moveSameSession(session, uidSet, destinationMailbox
  [, allowPendingExpunge [, preferNative [, destinationRole]]]) — `destinationRole` is required by the high-level executor`
* `ImapTransferOps~commitSourceRemoval(session, uidSet [, allowPendingExpunge])`
* `ImapTransferOps~fetchTransferMetadata(session, uidSet)`
* `ImapTransferOps~appendableFlags(flags [, preserveDeleted])`

`ImapCopyUidResult` preserves `[COPYUID uidvalidity source-set destination-set]` as
compact UID sets and can map an individual source UID to its destination UID without
materializing a large set.

`ImapMoveResult~complete` means both destination acceptance and required source
removal completed. A pending-expunge fallback is visible as `pendingExpunge=.true`
and is not reported as a complete move.

The high-level same-session move API intentionally authorizes only `ORDINARY`
destination role in dev8. Sent/Drafts/Junk/Trash/Archive require explicit server
semantics; raw `uidMove()`/`uidCopy()` remain available when the application owns that
policy.
