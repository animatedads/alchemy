# Database promotion basis boundary — v0.31-work

Database transaction/retry provenance is useful audit basis for a promotion, but it is not itself authorization.

`DatabaseTransactionPromotionBasisAdapter~basisFrom()` accepts only detached `DatabaseTransactionEvidence` whose `promotionEligible` flag is false and returns an `EvidencePromotionBasis` with kind `DATABASE_TRANSACTION_EVIDENCE` and id equal to the evidence identity.

`promotionsFrom()` always refuses with `DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY`.

This preserves the distinction:

```text
provenance basis != promotion authority
```
