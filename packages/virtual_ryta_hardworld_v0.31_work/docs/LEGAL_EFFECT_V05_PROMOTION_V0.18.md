# Legal Effect v0.5 promotion boundary — v0.18

## Purpose

This adapter does not implement legal semantics. `legal_effect_v0.5` owns source verification, legal
compilation, applicability, modification, conflict and authority resolution. v0.18 owns the narrower boundary
at which a Legal Effect assessment is allowed to become an authority-bearing `EvidencePromotion`.

## Admission chain

```text
native/authoritative legal bytes
    -> LegalSourceVerifier
    -> cryptographically verified LegalSourceIdentity
    -> verified LegalProvisionReference
    -> LegalCompilationUnit
    -> frozen LegalCompilationSnapshot
    -> LegalRuleCompiler
    -> LegalCompilationCertificate
    -> publication-eligible sealed LegalRuleGeneration
    -> pinned LegalEffectEngine evaluation
    -> EvidencePromotion
    -> explicit EvidencePromotionApplier
    -> HardWorld fact
```

A manually sealed generation is deliberately rejected for authority promotion.

## Independent identities

v0.18 binds five legal-generation dimensions:

1. Legal Effect `semanticIdentity`.
2. A conservative execution-order identity covering generation order and rule-internal order the evaluator can
   observe.
3. Compiler certificate `inputIdentity`.
4. Hash of the certificate's public canonical contract.
5. Hash of every cryptographically verified source and provision identity present in the generation.

The evaluation envelope additionally binds the proposed action and current legal context before and after
evaluation.

These identities answer different questions and must not be substituted for one another.

## Why execution identity remains necessary

Legal Effect v0.5 still has an observable reducer-order case for ungrouped `REVIEW/STATUS_EFFECT` and
`REQUIRES_OBLIGATION`. Reversing norm insertion order can change final status while semantic identity remains
equal. v0.18 therefore:

- binds the observed order into `executionIdentity`;
- refuses such an assessment for authority with `LEGAL_STATUS_REDUCTION_AMBIGUOUS`.

HardWorld does not guess legal precedence.

## Certificate validation is duck typed

The adapter deliberately does not compare the certificate's class object to `.LegalCompilationCertificate`.
ooRexx package namespaces make that an unsafe integration dependency. The bridge validates the public
certificate contract it needs (`canonicalText`, `inputIdentity`, compiler identity and counts).

The same provider-neutral rule used for NoSQLServer metadata is therefore applied at the legal package
boundary: depend on behaviour/contract, not accidental global class identity.

## Promotion basis

Every promotion includes auditable basis rows for:

- the v0.5 legal generation;
- compilation certificate;
- every verifier-backed source identity;
- every verifier-backed provision reference;
- proposed action;
- actual assessment status;
- effective controlling legal norms;
- resolved authority rules;
- unresolved norm/conflict evidence where review is required.

Suppressed norms are not controlling basis.

## Non-claims

- SHA-256 authenticates bytes, not the truth of issuer/jurisdiction metadata.
- v0.18 does not verify signatures or provenance outside Legal Effect's verifier contract.
- v0.18 does not repair Legal Effect's remaining reducer ambiguity.
- v0.18 does not infer that two Structured Relation fields have the same legal/business meaning; the caller or
  policy must make that semantic mapping explicitly.
