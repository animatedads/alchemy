# ooRexx Provenance Ledger v0.1-dev5

API: `provenance.ledger/0.1`

A small, non-financial cryptographically linked provenance ledger. It intentionally implements the useful ledger primitive, not cryptocurrency: no token, mining, wallet, smart-contract VM, or proof-of-work.

## Authority boundaries

- **Provenance Ledger owns:** canonical event encoding, transaction hashes, Merkle commitments, block chaining, signed commit records, and verification.
- **Crypto owns:** SHA-256 and Ed25519. This package uses `oorexx_crypto_v0.8.3` and does not copy cryptographic implementation.
- **Storage Fabric owns:** objects, namespaces, snapshots, byte movement, media, placement and lifecycle. The ledger stores references and commitments, never substitutes for Storage Fabric.
- **Institutional Policy / authority systems:** future commit/quorum policy seam.
- **Queue Fabric:** future replication seam. No consensus protocol is claimed.
- **Maths / ML:** future proof/evidence producers. ML observations must not silently become consensus truth.

## Executable surface

`ProvenanceTransaction` commits an operation against an object reference with before/after hashes, authority, evidence and policy references. Canonical encoding is length-prefixed to avoid ambiguous concatenation.

`ProvenanceMerkle` computes deterministic SHA-256 Merkle roots, duplicating the final node at odd levels.

`ProvenanceBlock` commits the chain id, height, predecessor, timestamp, Merkle root, transaction count, proposer and policy reference. Blocks can be signed and verified with Ed25519.

`ProvenanceLedger` creates sequenced transactions, constructs candidates, verifies them, commits them append-only, and verifies the chain.

## dev2
Adds optional duck-typed Storage Fabric and Accounting Core adapters plus immutable commit receipts. Neither Storage Fabric nor Accounting Core is a runtime dependency.

## dev3
Adds deterministic checkpoint state roots and durable provenance segments. Checkpoints bind a ledger head to object/digest commitments plus an optional Storage Fabric snapshot reference; objects remain outside the ledger.

## dev4
Adds explicit signed trusted anchors, anchored verification/restoration of non-genesis segments, imported sequence-resume handling, and independent portable archive manifests. Trust policy remains external; a signature-valid anchor is not automatically authorised.

## dev5
Adds media-neutral archive carriage and qualification against Storage Fabric dev17 sequential tape images. Storage Fabric remains an optional external carrier and is not a runtime dependency.
