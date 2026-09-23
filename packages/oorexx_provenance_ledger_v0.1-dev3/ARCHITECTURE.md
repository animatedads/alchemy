# Architecture

The central rule is: **the ledger records evidence of state transition; it does not become the storage system or universal source of truth.**

A transaction describes `objectRef`, operation, before/after commitments, authority, evidence and policy. A block cryptographically commits an ordered transaction set. Storage Fabric may later project or transport ledger artefacts, but remains independent.

## Planned seams

1. `StorageFabricProvenanceAdapter`: commit snapshot/resource identities and verify materialised state against ledger commitments.
2. durable append-only segment store with checkpoint/state-root records.
3. sequential-media codec for independently verifiable tape/card archival segments.
4. Queue Fabric replication protocol.
5. Institutional Policy governed N-of-M commit authority.
6. Maths proof references as independently verifiable transaction evidence.
7. Storage Relation/FUSE read-only projection for querying ledger history as namespace objects.

No distributed consensus, Byzantine-fault claim, or financial semantics are implied by `provenance.ledger/0.1`.


## Accounting boundary

Accounting Core and Provenance Ledger both retain immutable evidence history, but only Accounting Core owns accounting semantics. The provenance chain may commit accounting fingerprints; it cannot create postings, balances, periods, filings, or accounting truth.


## Durable segments and checkpoints (dev3)
A segment is transport, not consensus. Its import path reconstructs transactions and blocks and reruns cryptographic verification. v1 restoration intentionally requires a genesis-starting segment; partial-chain attachment is deferred until an explicit trusted checkpoint/anchor contract exists. A checkpoint commits a deterministic Merkle state root and optional snapshot reference without taking ownership of snapshot bytes.
