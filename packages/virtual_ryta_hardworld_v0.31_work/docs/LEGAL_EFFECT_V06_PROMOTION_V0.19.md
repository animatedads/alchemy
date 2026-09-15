# Legal Effect v0.6 promotion contract — Virtual RYTA / HardWorld v0.19

## Purpose

v0.19 consumes Legal Effect v0.6's verifier-issued source evidence and compiler-certificate snapshots without
making Legal Effect semantics part of HardWorld. The sequence is:

```text
rich source object
  -> LegalVerificationMaterial
  -> LegalSourceVerificationEvidence
  -> compiler certificate verification snapshots
  -> pinned LegalEffect assessment
  -> EvidencePromotion
  -> explicit EvidencePromotionApplier
  -> HardWorld fact
```

## Verification evidence bound by RYTA

For every source/provision verification evidence item v0.19 validates and binds:

- evidence identity and subject kind;
- source/provision/expression identity;
- representation and locator;
- expected and actual digest;
- verified/status fields;
- material length;
- verifier ID and verification timestamp;
- parent source-evidence identity for provisions.

The live bound evidence must match a detached snapshot present in the compilation certificate. Certificate
verification evidence count must exactly match the source/provision closure admitted by the generation.

The adapter deliberately consumes certificate snapshot objects through their public methods. It does not
instantiate `.LegalVerificationEvidenceSnapshot` by global class name; that would recreate the cross-package
class-identity coupling previously removed from the NoSQL adapter.

## Native objects

Certificate verification snapshots retain `sourceObject`. v0.19 exposes those snapshots as native promotion
basis objects so an auditor can follow the provenance chain back to the XML/Git/etc object.

Native object state is not included in authority identity unless it is represented by the verified digest.
A mutable object can drift after verification while the certificate continues to attest the earlier verified
representation. The v0.19 drift regression proves that distinction explicitly.

## Semantic identity versus execution identity

Legal Effect's `semanticIdentity` intentionally canonicalises insertion order. The current v0.6 reducer can
still observe norm insertion order for an ungrouped REVIEW/STATUS_EFFECT + REQUIRES_OBLIGATION combination.

Therefore v0.19 retains a second conservative execution fingerprint. If that ambiguous effective-disposition
combination is present without a controlling block/unresolved conflict, authority promotion is refused as
`LEGAL_STATUS_REDUCTION_AMBIGUOUS`.

## Conflict basis

- `effectiveMatches` can become controlling promotion basis.
- `suppressedMatches` remain audit/history evidence and are not cited as controlling effect.
- `resolvedConflicts` contribute the controlling `LegalAuthorityRule` to basis.
- `unresolvedConflicts` contribute review/unresolved basis.

## SQL boundary

The promotion relation is an audit surface. `SELECT` never applies a promotion and `UPDATE` is rejected by the
owning external provider. Application is an explicit call to `EvidencePromotionApplier`.
