# Known gaps — v0.1-dev7

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
