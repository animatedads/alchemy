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

Storage Fabric projection is initially READ_ONLY. Storage Fabric dev13 does not yet
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
