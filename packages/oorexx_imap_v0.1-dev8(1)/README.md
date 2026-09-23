# ooRexx IMAP/IMAPS v0.1-dev8

`oorexx_imap_v0.1-dev8` keeps **IMAP the application protocol** and makes transport security a separate, explicit configuration axis.

The library is designed for very large mailboxes. The motivating production mailbox has roughly **179k unread messages**, not 179k total messages. The disposable Gmail account is the controlled mutation laboratory; the large Dovecot account is the read-only scale sentinel. A broad implementation such as Citadel remains the next server-semantics qualification target.

## Transport security model

Canonical values are:

* `IMPLICIT_TLS` — TLS is established before the IMAP greeting; conventional IMAPS, usually port 993.
* `STARTTLS_REQUIRED` — connect as IMAP, negotiate `STARTTLS`, then continue the same session under TLS; usually port 143.
* `PLAINTEXT` — unencrypted transport. This exists for protocol diagnostics/private controlled environments; `login()` still refuses to send a password over it.

Compatibility aliases that are unambiguous are canonicalized: `IMAPS`, `IMAP_SSL`, `IMAP_OVER_SSL` -> `IMPLICIT_TLS`; `STARTTLS`, `IMAP_STARTTLS` -> `STARTTLS_REQUIRED`; `PLAIN` -> `PLAINTEXT`.

Bare labels such as `IMAP`, `TLS`, `SSL`, `SSL/TLS` and `SECURE` are rejected because they do not say whether TLS is implicit or negotiated with STARTTLS.

`ImapEndpoint` derives the conventional port only after the security mode is known. Explicit non-standard ports remain supported.

## Dev2 additions

* `ImapTransportSecurity` canonical policy model.
* `ImapEndpoint` separates host/port/security from the application protocol.
* `ImapSocketTransportConfig~security` replaces ambiguous `mode`; the dev1 `mode` attribute remains only as a compatibility alias and is canonicalized.
* `ImapSession~bootstrapSecurity()` performs the correct greeting/capability/STARTTLS sequence and refreshes capabilities after the TLS boundary.
* Every successful `CAPABILITY` command now replaces the previous capability snapshot instead of unioning stale pre-TLS/pre-auth capabilities.
* The read-only live probe accepts `IMPLICIT_TLS`, `STARTTLS_REQUIRED`, or `PLAINTEXT` explicitly.
* The live probe prefers `IMAP_PASSWORD_FILE` so a disposable Gmail App Password can live outside source, argv, logs and package state. `IMAP_PROBE_PASSWORD` is retained as a development-only fallback.
* `examples/gmail_readonly.sh` is configured for `imap.gmail.com:993`, `IMPLICIT_TLS`, and `$HOME/googlepassword` by default.


## Dev3 packaging integration

Dev3 is package-manager native for `alchemy-preferred-packager` / schema `oorexx.package/0.1`:

* `OOREXX_PACKAGE.json` is at the ZIP archive root, as required by `PackageCandidate`.
* Package identity is `oorexx-imap / MAIN / moduleLevel 3`.
* Optional dependencies now carry an explicit `lineage: MAIN`, matching the packager dependency contract.
* Required package qualifications can run through the restricted Stage-0 `BootstrapRexxRunner`: each required test is `rexx <script>` and resolves package sources by relative path, so it does not depend on the package already being active in `REXX_PATH`.
* `rexxPath` remains `src`; activation is therefore a package-manager concern rather than an installer script mutating the user's environment.

Dev3 established Preferred-Packager package/install authority. Dev4 keeps the
wire protocol semantics while adding dependency-neutral structured diagnostics
and an optional ooRexx Logging v0.7 bridge.

## Existing large-mailbox invariants retained

* Durable identity uses mailbox + `UIDVALIDITY` + `UID`; sequence numbers remain live-session bookkeeping only.
* Typed background body retrieval uses `BODY.PEEK[...]` and rejects common `\\Seen`-mutating fetch forms.
* UID sets remain compact ranges.
* Literal framing is streaming and bounded.
* Oversized response literals are not accumulated in memory by default.
* `ESEARCH` COUNT/MIN/MAX/ALL can remain compact.
* Generic `command()` keeps the full protocol surface available even when a typed wrapper has not yet been written.
* APPEND can stream a source rather than requiring one giant String.
* Storage Fabric remains an optional large-body/attachment sink seam rather than an IMAP-core dependency.

## Disposable Gmail read-only probe

The package does **not** contain a password. For the test account:

```sh
chmod 600 "$HOME/googlepassword"
export IMAP_PASSWORD_FILE="$HOME/googlepassword"
export IMAP_OPENSSL_BRIDGE=/path/to/oorexx_api_client/bridge
./examples/gmail_readonly.sh
```

The probe uses `EXAMINE`, `STATUS`, capability discovery and login. It performs no STORE, MOVE, DELETE or EXPUNGE operation.

The build container cannot access the user's local `~/googlepassword`, so live Gmail evidence is carried forward from the successful operator run rather than rerun during packaging.

## Live qualification evidence carried forward

Operator-reported live read-only qualification has now succeeded on both:

* Gmail (`imap.gmail.com:993`, `IMPLICIT_TLS`): TLS established, 15 capabilities, INBOX 38 messages / 30 unseen, read-only probe exit 0.
* Dovecot (`anduin.net:993`, `IMPLICIT_TLS`): 9 capabilities, INBOX 196,662 messages / 178,388 unseen, read-only probe exit 0.

These runs exercised mailbox metadata and read-only selection; they are not yet evidence of full-corpus body retrieval or indexing. Credentials were kept outside package state and command-line arguments.


## Structured logging seam (dev4)

`ImapSession` accepts an optional event sink.  Core protocol operation never
requires the logging package; `ImapLoggingAdapter.cls` bridges the seam to
ooRexx Logging v0.7 when installed.  The adapter emits structured points such
as `COMMAND_BEGIN`, `COMMAND_COMPLETE`, `CAPABILITIES`, `SECURITY_READY`,
`AUTHENTICATION`, `MAILBOX_STATE`, `MAILBOX_STATUS`, `SEARCH_RESULT`,
`LITERAL_BEGIN` and `LITERAL_COMPLETE`.

The diagnostic contract is intentionally metadata-only.  It never passes raw
LOGIN/AUTHENTICATE command text, passwords, usernames, message bodies, header
blocks or literal bytes to logging.  A logging-target failure is recorded in
`session~lastEventError` but is fail-open with respect to the IMAP wire state,
so observability cannot strand a live protocol exchange after a command has
been sent.


## Dev5 mutation semantics and test portability

Dev5 fixes the remaining package-root test invocation issue: test sources now resolve
IMAP classes through the runner-provided `REXX_PATH`, rather than `../src` paths that
depended on the current working directory.

It also introduces `ImapSemantics.cls`.  Raw IMAP APPEND remains available, but the
new intent-aware helpers distinguish passive storage/migration from posting and
submission.  The explicit Citadel profile models room APPEND as POST, Sent APPEND as
SUBMIT, and declares that Citadel SMTP already records Sent so clients do not append a
second copy.  See `SERVER_BEHAVIOR.md`.

## Dev6 bidirectional IMAP qualification surface

Dev6 extends the write side without changing the existing raw protocol contract:

* typed `CREATE`, `DELETE`, `RENAME`, `SUBSCRIBE`, `UNSUBSCRIBE`, and `CLOSE` wrappers;
* `ImapAppendResult`, which parses UIDPLUS `APPENDUID` into compact `ImapUidSet` state without inventing a UID when the server does not return one;
* result-returning APPEND helpers, including the intent-aware semantic path;
* a gated live `imap-append-roundtrip-probe.rex` that creates a **new ordinary mailbox**, APPENDs one known message, identifies its UID, fetches it back with `BODY.PEEK[]`, and verifies the bytes.

The live mutation probe requires `IMAP_MUTATION_ENABLE=YES`, refuses INBOX, and
refuses to append into an existing mailbox because `CREATE` must succeed first. It
**retains** the created mailbox/message by design: mailbox deletion/expunge semantics
are provider-specific (especially on Gmail) and are a separate qualification surface.
This prevents a protocol round-trip test from pretending it understands provider
cleanup semantics.

Example for the disposable Gmail account:

```sh
export IMAP_OPENSSL_BRIDGE=/path/to/api-client/bridge
export IMAP_PASSWORD_FILE="$HOME/googlepassword"
export IMAP_MUTATION_ENABLE=YES
./examples/gmail_append_roundtrip.sh
```

The generated mailbox name is unique unless `IMAP_TEST_MAILBOX` is supplied.
No live APPEND result is claimed by the package itself until an operator runs this
against the disposable account.


## Dev7 Storage Fabric projection + NoSQLServer search backing

Dev7 makes the first concrete bridge from IMAP identity into Storage Fabric dev13
without making Storage Fabric or FUSE part of the IMAP protocol core.

`ImapStorageFabricProjection.cls` projects a message identified by
`account + mailbox + UIDVALIDITY + UID` as one `StorageObject`.  Friendly paths such
as `IDX1 Subject <sender>` are names only; the durable StorageRef identity remains the
IMAP identity tuple.  IMAP metadata is exposed as Storage EAs, initial bindings are
READ_ONLY, and `ImapStorageRawByteSource` performs bounded ranged `BODY.PEEK[]` reads
rather than materialising a whole message in memory.  The semantic selector parser
preserves `:?subject`, `:?attachment:1:?filename`, and similar provider-level
selectors without claiming that Storage Fabric dev13 already resolves every selector.

The local catalogue/search projection is now deliberately backed by **NoSQLServer
v0.79** through `ImapNoSQLIndex.cls`.  NoSQLServer remains an external component; the
IMAP project does not fork its database/index implementation.

The index stores three kinds of derived state:

* `imap_messages` — compact UID-bound mailbox/message metadata;
* `imap_terms` — an inverted token relation for subject/from/message-id and optionally
  body text;
* `imap_mailboxes` — resumable mailbox indexing checkpoints (`UIDVALIDITY`, UIDNEXT,
  MODSEQ/progress watermarks).

NoSQLServer's own value indexes are built over the term and metadata relations.  Its
CURRENT/BEHIND + journal-delta behaviour therefore remains NoSQLServer's concern.
IMAP only supplies derived rows and bounded search requests.

Index publication is fail-closed: a message is marked `index_complete=0`, its old
terms are replaced, and it becomes searchable only after the replacement projection
is complete.  A crash can therefore hide an incompletely reindexed message until
repair, but cannot make partial new terms authoritative mailbox state.  The entire
index is disposable and rebuildable from IMAP/Storage authority.

`searchFrom("no-reply@accounts.google.com")` is an exact metadata query and does not
require downloading message bodies. `searchText("Facebook")` uses the local inverted
index; callers receive bounded results plus a `bodyCoverageComplete` indication rather
than a false claim that every remote body has already been indexed.

`ImapStorageNamespaceProjector~bindIndexResult()` converts database-neutral index hits
into the same StorageRefs used by direct IMAP projection.  This is the seam needed for
future live query folders and scriptable operations such as selecting Google account
mail and then moving the resulting Storage objects through an explicitly authorised
IMAP mutation route.

Dev7 does **not** yet claim that a FUSE `rename(2)` automatically dispatches `UID MOVE`.
Storage Fabric dev13's filesystem rename is still its own namespace operation.  A
provider mutation dispatch/control-plane seam must carry that intent before shell
`mv` is allowed to mutate a remote mailbox.

## Dev8: exact move and staged transfer semantics

Dev8 closes the gap between raw `UID MOVE`/`UID COPY` primitives and an operation that
can be safely used by Storage Fabric or automation:

* `ImapTransferOps~moveSameSession()` prefers RFC MOVE when `MOVE` is advertised.
* If MOVE is absent but `UIDPLUS` exists, it uses `UID COPY`, then
  `UID STORE +FLAGS.SILENT (\Deleted)`, then **`UID EXPUNGE <exact uid-set>`**.
* Plain `EXPUNGE` is never used as a fallback because it could remove unrelated
  messages already marked `\Deleted` by another actor.
* If neither MOVE nor UIDPLUS is available, the high-level move fails closed unless
  the caller explicitly accepts a `MARK_DELETED_ONLY` result with pending expunge.
* A failed COPY never starts source deletion; a failed mark-deleted never proceeds to
  expunge.
* High-level moves reject the source mailbox as the destination and reject special-use
  destination roles until explicit server policy exists. Raw protocol commands remain
  available to applications that intentionally own vendor semantics.

For cross-server/account migration the protocol is deliberately staged:

```text
FETCH metadata + BODY.PEEK[]
        -> APPEND destination
        -> verify destination
        -> explicit commitSourceRemoval(source UID)
```

Source removal is therefore a COMMIT operation, not an automatic side effect of
APPEND. `fetchTransferMetadata()` supplies UID/FLAGS/INTERNALDATE/RFC822.SIZE and
`appendableFlags()` strips `\Recent` and, by default, `\Deleted` before APPEND.

Two opt-in live probes are supplied for sacrificial accounts:

* `examples/gmail_move_roundtrip.sh` — native MOVE when available, exact fallback only
  when safe.
* `examples/gmail_append_delete_roundtrip.sh` — deliberately exercises
  APPEND -> byte verification -> exact source removal. It requires the additional
  `IMAP_TRANSFER_DELETE_ENABLE=YES` gate.

Neither probe touches INBOX and both require newly-created ordinary mailboxes.
