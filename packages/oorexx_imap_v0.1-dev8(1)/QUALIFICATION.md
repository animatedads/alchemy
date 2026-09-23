# Qualification — dev7

## Offline/core

Required tests cover:

* explicit/canonical transport security labels and default ports;
* deliberate rejection of ambiguous `IMAP`, `TLS`, and `SSL` labels;
* compact million-entry UID ranges;
* bounded streaming literals and line limits;
* tagged/untagged response collection;
* EXAMINE state parsing;
* ESEARCH compact count/ranges;
* APPEND literal flow;
* `BODY.PEEK` guard.

## Optional dependency integration

With supplied API Client / Foreign Runtime / Storage Fabric dependencies:

* transport adapter load;
* direct literal -> Storage Fabric sink;
* local implicit-TLS IMAP socket test;
* local mandatory-STARTTLS test;
* post-STARTTLS `CAPABILITY` snapshot replacement (pre-TLS STARTTLS/LOGINDISABLED capabilities do not leak into the post-TLS snapshot).

## First external qualification — disposable Gmail (~100 messages)

Use `IMPLICIT_TLS`, port 993 and an App Password kept outside the package.

1. certificate and hostname verification;
2. greeting + CAPABILITY;
3. authentication without password argv/logging;
4. post-auth CAPABILITY refresh;
5. EXAMINE INBOX;
6. STATUS counts/UID metadata;
7. bounded UID metadata fetch;
8. selected `BODY.PEEK` retrieval;
9. reconnect and compare UIDVALIDITY/UID state;
10. prove no `\\Seen`, delete, move or expunge side effects.

No live Gmail run is claimed in this package because the build container cannot read the user's local `~/googlepassword`.

## Later broad-server qualification

Use Citadel or another broad implementation for NAMESPACE, ACL, QUOTA, METADATA, SORT, THREAD, UIDPLUS/MOVE, IDLE, CONDSTORE/QRESYNC and other advertised extensions.

## Preferred Packager qualification

The required qualification declarations are intentionally compatible with the Stage-0 runner:

* command shape is exactly `rexx <script>`;
* `cwd` is `tests`;
* each required test references IMAP classes via `../src/...`, so the candidate package need not already be active;
* optional TLS / Foreign Runtime / Storage Fabric interoperability remains outside Stage-0 and is qualified with the normal runtime.

The dev2 manifest is intentionally *not* reused unchanged: the preferred packager requires every dependency object, including optional requirements, to declare `lineage`, and it requires `OOREXX_PACKAGE.json` at archive root.

## Live evidence (operator reported)

* Gmail: `IMPLICIT_TLS` 993, TLS established, 15 capabilities, INBOX 38 / UNSEEN 30, read-only, rc 0.
* anduin.net Dovecot: `IMPLICIT_TLS` 993, 9 capabilities, INBOX 196662 / UNSEEN 178388, read-only, rc 0.

Both are metadata/read-only qualification. Full bounded UID metadata/body fetch qualification remains the next live step on the disposable Gmail account.


## dev4 diagnostics qualification

`test_diagnostics.rex` is a required dependency-free test.  It proves that a
raw generic LOGIN command containing a sentinel username/password produces only
the safe `LOGIN` command name in diagnostics, and that a throwing diagnostic
sink cannot break a completed IMAP protocol operation.

`test_logging_adapter.rex` is an optional integration test against ooRexx
Logging v0.7.  It proves IMAP points are delivered as structured `LogEvent`
objects to a `LogMemoryTarget`.

## dev5 semantic and invocation qualification

Two required pure-ooRexx tests are added:

* `test_semantics.rex` validates generic and Citadel behaviour profiles, including the
  Citadel SMTP/Sent duplicate-prevention rule.
* `test_append_intent.rex` proves intentional Citadel Sent submission reaches APPEND
  while a restore into Citadel Sent is rejected before any wire write.

The dev4 test-runner packaging lesson is also fixed: required tests no longer use
working-directory-relative `../src/...` `::requires`.  `tests/run.sh` was qualified
both from the package root and from an unrelated working directory using its own
absolute package root and `REXX_PATH` construction.

No live Citadel mutation is claimed by dev5.  The Citadel semantics are an explicit
compatibility profile based on supplied operational behaviour and remain separate
from the already-live-qualified Gmail/Dovecot read-only evidence.

## Dev6 qualification

Required offline suite adds:

* `test_append_result.rex` — UIDPLUS APPENDUID parsing, including compact ranged UID sets and the no-UIDPLUS case.
* `test_mailbox_mutation.rex` — CREATE/RENAME/SUBSCRIBE/UNSUBSCRIBE/EXAMINE/CLOSE/DELETE wire contracts and selected-state clearing.

The live mutation probe is intentionally **not** a required package qualification because
it changes a remote account. It is operator-gated with `IMAP_MUTATION_ENABLE=YES`.


## Dev6 live mutation evidence carried into dev7

Preferred Packager generation 2 committed dev6 and its 12/12 required suite passed.
The gated Gmail mutation round trip succeeded in mailbox
`OO-IMAP-QUAL-20260916-140822-2`: UIDVALIDITY 13, UID 1, exact 323-byte APPEND followed
by BODY.PEEK byte comparison PASS. The mailbox/message were intentionally retained and
credential contents were not recorded.

## Dev7 qualification

Required dependency-free suite is now **13/13**, adding `test_index_core.rex` for
stable UID identity, sender normalization and bounded exact-token behaviour. It was
run both from the package tree and through the CWD-independent runner.

Optional integrations additionally pass against the supplied components:

* `test_storage_adapter.rex` — direct literal -> Storage Fabric sink;
* `test_storage_projection.rex` — Storage Fabric dev13 StorageRef/EAs/READ_ONLY
  projection, semantic selector parsing and database-neutral index-result projection;
* `test_nosql_index.rex` — NoSQLServer v0.79 schema creation, metadata/body term
  indexing, NoSQL value-index construction, exact sender search, multi-term AND search,
  stale-term replacement through NoSQL journal-delta reconciliation, and mailbox
  progress checkpoint persistence;
* `test_logging_adapter.rex` — Logging v0.7 integration retained.

The NoSQL test uses the real supplied NoSQLServer source rather than a fake database.
The index remains derived/rebuildable; no test treats it as mail authority.

## Dev8 qualification

Required dependency-free suite adds:

* `test_uid_mapping.rex` — compact COPYUID mapping, including non-materializing ordinal
  mapping across UID ranges.
* `test_move_semantics.rex` — native MOVE, exact COPY/STORE/UID EXPUNGE fallback,
  fail-closed no-UIDPLUS behaviour, explicit pending-expunge mode, special-use and
  same-mailbox rejection, and no-delete-after-copy/store-failure guarantees.
* `test_transfer_commit.rex` — transfer metadata parsing, safe APPEND flag projection,
  observational PREPARE versus explicit source-removal COMMIT, and read-only refusal.

Local real-socket TLS integration now also includes:

* `test_move_transport.rex` against a TLS IMAP server advertising MOVE+UIDPLUS.
* `test_move_fallback_transport.rex` against a TLS IMAP server advertising UIDPLUS but
  no MOVE, proving actual COPY -> STORE -> UID EXPUNGE wire sequencing.

The live Gmail probes remain opt-in and are not package-manager-required tests.
