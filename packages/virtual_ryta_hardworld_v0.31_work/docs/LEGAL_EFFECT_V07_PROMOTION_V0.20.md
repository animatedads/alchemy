# Legal Effect v0.7 promotion boundary — HardWorld v0.20

## Authority construction

HardWorld may promote only a pinned, compiler-certified, verifier-backed Legal Effect v0.7 assessment.

Authority identity is:

```text
LEGAL_EFFECT/0.7/<generation-id>
  @ SHA256(legal semantic identity)
  + SHA256(conservative observable execution-order closure)
  + cert:SHA256(compiler certificate canonical text)
  + verified:SHA256(verifier/certificate closure)
```

Runtime Registry generation, artifact, package and lifecycle state are not part of this authority identity.

## Verification closure

`LegalEffectV07GenerationSnapshot` requires the compiler certificate's `verificationEvidence` collection. Every certificate snapshot must be verified and uniquely identified. Every live source/provision identity must expose verifier-issued evidence, and that evidence must match the certificate snapshot across all public verification fields.

Provision evidence must point to the exact source verification evidence bound to its source identity.

The adapter refuses missing, duplicate, unverified or mismatching verifier evidence.

## Promotion basis

Each promotion retains:

```text
LEGAL_GENERATION_V07
LEGAL_COMPILATION_CERTIFICATE
LEGAL_VERIFIED_SOURCE
LEGAL_SOURCE_VERIFICATION_EVIDENCE
LEGAL_VERIFIED_PROVISION
LEGAL_PROVISION_VERIFICATION_EVIDENCE
LEGAL_ACTION
ASSESSMENT_STATUS
LEGAL_NORM_EFFECTIVE / LEGAL_NORM_UNRESOLVED
LEGAL_AUTHORITY_RULE / LEGAL_CONFLICT_UNRESOLVED
```

If a Runtime Registry execution envelope is supplied, it additionally retains detached runtime provenance:

```text
LEGAL_RUNTIME_EXECUTION
UPSTREAM_RUNTIME_EXECUTION
```

## Source-code evidence chain

The v0.20 integration uses Structured Relation v0.8's public Bitcoin Core #35688 semantic/value-flow corpus. `RemoteSourceFileRevision~verifyBlobIdentity` confirms both carried snapshots against Git's canonical blob object ID before the business fact is created.

The final HardWorld review-required fact retains the original semantic-change object, and therefore both exact remote file revisions and their `GIT_BLOB_BOUND` provenance.

## Complex rich diagnostics

Code-analysis diagnostics contain ordered evidence arrays rather than only scalar strings. `StructuredEvidenceDiagnosticRecord` now canonicalises these via explicit revision/span/semantic fields. It does not invoke an arbitrary object's string conversion to obtain authority identity.

## Fail-closed reducer guard

Legal Effect v0.7 still has a known ungrouped status-reduction ambiguity. The pinned evaluator detects the observable `REVIEW/STATUS_EFFECT` + `REQUIRES_OBLIGATION` combination when no blocking/unresolved conflict semantics establish precedence and refuses promotion as `LEGAL_STATUS_REDUCTION_AMBIGUOUS`.
