# Provenance Ledger versus Accounting Core

They are close relatives because both preserve ordered, immutable, evidence-bound history. They are not interchangeable.

**Accounting Core** owns accounting semantics: legal-entity books, balanced postings, periods, executable accounting policy, reporting boundaries, sealed reporting snapshots, attestations, submissions and filing lifecycle. Its journal is authoritative accounting history.

**Provenance Ledger** owns generic cryptographic history: canonical event commitments, Merkle aggregation, hash chaining, signatures and independent verification across arbitrary object/state domains. It does not know debit/credit, legal entity, reporting period, filing meaning, or accounting consequence.

The integration direction is therefore one-way at the semantic boundary: Accounting Core may publish immutable accounting evidence identities/fingerprints into Provenance Ledger. The ledger proves that a particular accounting artefact or lifecycle observation was committed in a particular chain position under a particular authority; it never turns that commitment into an accounting posting and never supersedes Accounting Core's own journal/evidence lifecycle.

This same rule applies to Storage Fabric: Storage owns bytes, objects, snapshots and verification digests; Provenance Ledger commits their identities and state transitions without becoming storage.