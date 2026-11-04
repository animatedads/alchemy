# Known gaps — v0.1-dev13

* No typed IDLE state machine yet.
* No SASL/OAuth provider yet; the disposable Gmail path currently uses an App Password through LOGIN over verified TLS.
* Typed NAMESPACE/ACL/QUOTA/METADATA/SORT/THREAD wrappers are not yet implemented; the generic command surface remains available.
* Live Gmail and Dovecot read-only metadata qualification has succeeded; no live Citadel qualification is claimed yet.
* No migration journal/plan-run-verify-commit implementation yet.
* `COMPRESS=DEFLATE` is not enabled. The supplied compression package exposes useful compression capability, but correct IMAP COMPRESS requires a persistent incremental deflate/inflate stream for the remainder of the session. Whole-buffer compression is insufficient and would violate the bounded-streaming design.


## Diagnostics boundary

Dev4 provides structured metadata diagnostics and the ooRexx Logging v0.7
adapter. A raw wire trace facility is intentionally not provided because IMAP
commands and literals can contain credentials and complete private message
content. Future protocol debugging must preserve the same redaction boundary.

## dev7 remaining integration work

The dev6 Gmail APPEND/BODY.PEEK exact-byte round trip is now operator-qualified.
Provider-specific cleanup is still not qualified, and no live Citadel POST/SUBMIT
mutation is claimed.

Dev7 adds persistent NoSQLServer metadata/term/checkpoint storage, but live mailbox
ingestion is not yet wired into an automatic background synchronizer. MIME body text
extraction, attachment relations, HTML-to-text normalization, ranking, stemming,
phrase search and Unicode-aware tokenization remain future work. The current tokenizer
is deliberately simple ASCII-oriented exact-token indexing.

Storage Fabric projection is initially READ_ONLY. Storage Fabric dev15 does not yet
dispatch a FUSE rename/unlink to an IMAP provider mutation executor, so shell `mv` is
not claimed as a remote UID MOVE operation in this cut. The control plane must make
that mapping explicit before enabling it.

## Dev8 remaining transfer gaps

* Live Gmail dev8 MOVE and APPEND/verify/delete probes are packaged but not executed in
  this build environment because the account credential lives on the operator host.
* Citadel COPY/MOVE semantics for special-use rooms are intentionally unqualified;
  high-level moves to non-ordinary roles fail closed.
* Cross-server streaming can be supplied by Storage Fabric's byte-source/sink layer;
  the IMAP core does not invent a second resumable transfer engine.
* Without UIDPLUS, a server lacking MOVE cannot be given exact expunge semantics by
  generic IMAP. The only permitted fallback is explicit `MARK_DELETED_ONLY` with a
  visible pending-expunge state.

## Dev10 server gaps

The dev10 server is a deliberately partial server core, not a full IMAP4rev1
server. The following remain open and are therefore not advertised:

* server APPEND and streaming literal ingestion;
* FETCH / UID FETCH and bounded literal production;
* STORE / UID STORE and flag concurrency semantics;
* SEARCH / UID SEARCH against a mailbox provider/index;
* COPY/MOVE, exact EXPUNGE and UIDPLUS server response semantics;
* IDLE and multi-session unsolicited state changes;
* CONDSTORE/QRESYNC server semantics;
* complete LIST reference/wildcard hierarchy grammar;
* live socket/TLS listener qualification;
* real LDAP-network qualification of the IMAP adapter;
* Access Permissions mailbox-authority adapter;
* Storage Fabric-backed server mailbox provider.

The 27 September portfolio review also marks LDAP Identity and Storage Fabric
candidates as still requiring their own manual review. IMAP does not treat their
presence as transitive qualification.

## Storage semantic compatibility

Storage Fabric dev23 removed the legacy `StorageSemantic.cls` API. Dev10's normal projection no longer depends on it and is qualified against dev23. The separate `ImapStorageFabricLegacySemantic.cls` compatibility adapter remains unqualified against current dev23 by design because the required legacy package is absent.
\n\n## Dev11 remaining server gaps\n\nDev11 is still intentionally not advertised as IMAP4rev1. Remaining gaps include SASL `AUTHENTICATE`, `IDLE`, complete SEARCH grammar, complete FETCH data-item/section grammar, MIME/body-section partials, server-side BODY[] `\\Seen` side-effect qualification, conditional STORE/UNCHANGEDSINCE, CONDSTORE/QRESYNC/VANISHED, unsolicited multi-session updates, robust LIST wildcard/reference semantics, persistent mailbox provider recovery, and live external-client interoperability qualification. The in-memory message provider is qualification-only.\n\nThe new Socket Provider binding is transport acquisition/framing only; TLS policy and certificate/key authority remain with the selected secure socket/TLS provider. IMAP does not infer that an ordinary TCP endpoint is encrypted.\n

## Dev12 instrumentation gaps

Instrumentation Mesh v0.1-dev3 is consumed as an optional observation plane.
Dev12 does not yet publish per-operation streaming progress for large APPEND/FETCH
transfers because the current server endpoint still acquires an announced APPEND
literal through one bounded `readExact(n)` call. When the server gains a truly
streaming literal source/sink path, progress should be emitted under stable
operation ids rather than inventing a separate progress protocol.

No remote instrumentation management command is exposed by IMAP dev12. That is
deliberate: telemetry permission is not mailbox/session mutation authority.

## Dev13 remaining server gaps

* IDLE/change-feed qualification is currently dependency-free/in-process plus the
  Socket Provider readiness adapter.  No live Thunderbird/OpenSSH-style external
  IMAP client interoperability run is claimed for IDLE yet.
* The reference `ImapMemoryMailboxProvider` retains only a bounded in-memory change
  log.  Restart-safe/multi-process providers need a durable provider-owned cursor and
  replay source; Instrumentation Mesh history must not be substituted for that
  protocol-state authority.
* Change kinds currently cover EXISTS, FLAGS and EXPUNGE.  Richer unsolicited state
  (including extension-specific MODSEQ/QRESYNC evidence) remains future work.
* Full FETCH/SEARCH grammar, BODY side effects, CONDSTORE/QRESYNC, SASL breadth and
  complete IMAP4rev1 conformance are still open; the server therefore continues to
  advertise the explicit ooRexx capability markers instead of `IMAP4rev1`.

