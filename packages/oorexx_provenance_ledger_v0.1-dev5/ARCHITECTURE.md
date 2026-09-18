# Architecture

The central rule is: **the ledger records evidence of state transition; it does not become the storage system or universal source of truth.**

A transaction describes `objectRef`, operation, before/after commitments, authority, evidence and policy. A block cryptographically commits an ordered transaction set. Storage Fabric may project or transport ledger artefacts, but remains independent.

## Boundaries and seams

1. Storage Fabric adapters commit snapshot/resource identities and verify materialised state against ledger commitments.
2. Durable segments and checkpoint/state-root records carry independently verifiable history.
3. Media carriage is transport, not ledger or storage authority.
4. Queue Fabric replication is a future seam, not current consensus.
5. Institutional Policy may govern N-of-M commit authority without being embedded in the ledger.
6. Maths proof references may be independently verifiable transaction evidence.
7. Storage Relation/FUSE may provide read-only projections for querying history as namespace objects.

No distributed-consensus, Byzantine-fault-tolerance, or financial-semantics claim is implied by `provenance.ledger/0.1`.

## Accounting boundary

Accounting Core and Provenance Ledger both retain immutable evidence history, but only Accounting Core owns accounting semantics. The provenance chain may commit accounting fingerprints; it cannot create postings, balances, periods, filings, or accounting truth.

## Durable segments, checkpoints, anchors

A segment is transport, not consensus. Its import path reconstructs transactions and blocks and reruns cryptographic verification. Checkpoints commit deterministic Merkle state roots plus optional snapshot references without taking ownership of snapshot bytes.

A non-genesis segment is accepted only against explicit trusted-anchor material at exactly the preceding height. Signature validity proves cryptographic provenance; external policy decides whether that signer is authoritative.

## Media carriage

`ProvenanceMediaAdapter` is media-neutral and duck-typed. It can place self-verifying provenance envelopes into Storage Fabric dev17 sequential-media images while preserving the dependency direction: Storage Fabric does not require or understand Provenance Ledger.
