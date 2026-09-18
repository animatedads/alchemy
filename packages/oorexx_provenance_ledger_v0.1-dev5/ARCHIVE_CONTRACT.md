# Portable archive contract — dev4

A provenance archive is transport packaging, not a new storage authority.

* `PROVENANCE-ANCHOR|1` is explicit signed trust material binding chain id, historical height/head, optional state root and optional Storage Fabric snapshot reference.
* `PROVENANCE-SEGMENT|1` remains the independently verifiable block stream. A non-genesis segment is admissible only against an explicitly supplied, signature-valid anchor at exactly `fromHeight - 1`.
* `PROVENANCE-ARCHIVE|1` is an independent manifest committing to an anchor hash and named segment ranges/digests. The manifest does not embed objects or snapshots.
* Storage Fabric may carry any of these bytes on files, object storage, tape or other media. Provenance Ledger does not claim ownership of that media.

Loaded signatures are evidence. Whether an anchor signer is trusted remains an external authority/policy decision; dev4 deliberately does not invent a trust store.
