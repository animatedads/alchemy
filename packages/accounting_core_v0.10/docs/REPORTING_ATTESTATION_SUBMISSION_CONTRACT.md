# Reporting attestation and submission evidence (`accounting.reporting.attestation/0.1`, `accounting.reporting.submission/0.1`)

v0.9 adds an evidential layer above `accounting.reporting.snapshot/0.1`. It does not change journal posting, live reporting, report population sealing or regulator-specific reporting policy.

## Why this is separate

A sealed accounting snapshot answers **what accounting population was reported**. An attestation answers **who claimed to approve/sign that exact snapshot, under which asserted authority and key identity**. Submission evidence answers **what exact snapshot/attestation set was sent and what external receipt/status was returned**.

These are deliberately separate objects. Discovery of a later/backdated journal can make the old snapshot population stale without invalidating the evidence that the old snapshot was actually approved and filed.

## Attestation payload

`AccountingReportingEvidenceService~createAttestation()` builds a deterministic `accounting.reporting.attestation.payload/0.1` payload containing:

- exact snapshot id and snapshot fingerprint
- exact reporting-boundary fingerprint
- attestation type and purpose
- attestor reference
- semantic authority reference and immutable authority identity
- occurrence time supplied by the caller
- proof scheme and digest algorithm
- key reference and immutable key identity
- evidence references and metadata

The proof provider signs/seals that exact payload. The resulting `AccountingReportingAttestation` retains the proof and has its own deterministic fingerprint/projection.

Accounting Core does **not** infer that `attestorRef` owns the key, that `authorityIdentity` is legally effective, or that the attestor had permission to sign. Those are attribution/authority questions for Crypto, Access Permissions, Security Effect, Institutional Policy, Legal Effect or a regulator-specific policy layer. The crucial accounting guarantee is that the claimed identities are inside the proof payload and cannot be changed without invalidating the proof.

## Proof-provider boundary

The core proof contract is dynamic and algorithm-neutral. A provider/verifier exposes:

- `schemeRef`
- `digestAlgorithmRef`
- `keyRef`
- `keyIdentity`
- `createProof(payload)` for signing providers
- `verifyProof(payload, proof)` for verifiers

The optional `AccountingReportingCrypto.cls` adapter qualifies Crypto v0.8.3 SHA-256 + Ed25519. Ordinary Accounting Core posting/reporting does not require Crypto.

The package vendors the exact Crypto v0.8.3 `crypto.cls` used for standalone qualification and records both source ZIP and source-file digests. In the consolidated ecosystem the normal dependency is the roll-up's `oorexx_crypto_v0.8.3` component.

## Submission evidence

`AccountingReportingSubmissionEvidence` freezes:

- exact snapshot id/fingerprint and boundary fingerprint
- exact set of attestation ids/fingerprints included with the submission
- reporting authority and submission channel
- occurrence time supplied by the caller
- external submission reference
- submission/receipt status
- optional received time
- external receipt reference and immutable receipt identity
- evidence references and metadata

`verifySubmissionEvidence()` rejects substitution/removal of attestations or a different snapshot. Accounting Core does not contact the regulator and does not decide what an external status means legally.

## Historical correction invariant

A subsequent source-book correction may produce:

`AccountingReportingService~verifySnapshot(oldSnapshot, ...) -> REPORT_POPULATION_STALE`

while simultaneously:

`verifyAttestation(oldAttestation, oldSnapshot, verifier) -> VERIFIED`

and:

`verifySubmissionEvidence(oldSubmission, oldSnapshot, oldAttestations) -> VERIFIED`

This is intentional. The former answers whether the old report is still complete against today's recovered accounting population; the latter two prove what was actually approved/submitted at the time.
