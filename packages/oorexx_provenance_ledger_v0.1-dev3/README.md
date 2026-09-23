# ooRexx Provenance Ledger v0.1-dev3

API: `provenance.ledger/0.1`

A small, non-financial cryptographically linked provenance ledger. It intentionally implements the useful ledger primitive, not cryptocurrency: no token, mining, wallet, smart-contract VM, or proof-of-work.

## Authority boundaries

- **Provenance Ledger owns:** canonical event encoding, transaction hashes, Merkle commitments, block chaining, signed commit records, and verification.
- **Crypto owns:** SHA-256 and Ed25519. This package uses `oorexx_crypto_v0.8.3` and does not copy cryptographic implementation.
- **Storage Fabric owns:** objects, namespaces, snapshots, byte movement, media, placement and lifecycle. The ledger stores references and commitments, never substitutes for Storage Fabric.
- **Institutional Policy / authority systems:** future commit/quorum policy seam. dev1 has a single-authority signed-block primitive only.
- **Queue Fabric:** future replication seam. No consensus protocol is claimed in dev1.
- **Maths / ML:** future proof/evidence producers. ML observations must not silently become consensus truth.

## dev1 executable slice

`ProvenanceTransaction` commits an operation against an object reference with before/after hashes, authority, evidence and policy references. Canonical encoding is length-prefixed to avoid ambiguous concatenation.

`ProvenanceMerkle` computes deterministic SHA-256 Merkle roots, duplicating the final node at odd levels.

`ProvenanceBlock` commits the chain id, height, predecessor, timestamp, Merkle root, transaction count, proposer and policy reference. Blocks can be signed and verified with Ed25519.

`ProvenanceLedger` creates sequenced transactions, constructs candidates, verifies them, commits them append-only in memory, and verifies the complete chain.

Persistence, Storage Fabric projections, snapshot checkpoints, tape/card export, Queue Fabric replication and quorum policy are deliberately subsequent slices. The dev1 object model is shaped so those can be added without making Storage Fabric depend on the ledger.


## dev2 seams

dev2 adds an optional duck-typed Storage Fabric adapter, immutable commit receipts, and a deliberately narrow Accounting Core evidence adapter. See `ACCOUNTING_BOUNDARY.md`. Neither Storage Fabric nor Accounting Core is a runtime dependency.


## dev3
Adds deterministic checkpoint state roots and a durable, line-oriented provenance segment codec. Segments contain canonical transaction fields and signed block material, can be restored from genesis, and are reverified on import. Checkpoints bind a ledger head to a set of object/digest commitments plus an optional Storage Fabric snapshot reference; objects remain outside the ledger.
