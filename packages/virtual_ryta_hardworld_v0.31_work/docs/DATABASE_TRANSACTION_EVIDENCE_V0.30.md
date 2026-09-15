# Database transaction/retry evidence boundary — v0.30-work

## Rule

```text
logical database transaction != physical execution attempt
database retry evidence       != business action
database provenance           != RYTA authority
```

Database Core v0.43 introduces stable logical transaction identity and an ordered physical attempt trail. RYTA consumes those surfaces through the optional `DatabaseTransactionEvidenceAdapter`; Database Core remains an external read-only dependency.

The adapter requires `transactionId`, result status/outcome/error, operation count, ordered attempts and optional execution context. Every physical attempt must retain the same logical transaction id and Database Core's deterministic `<transaction>:attempt:<n>` identity.

Database Core exposes its attempts Array directly, so RYTA copies it at capture time. Later source-array mutation cannot rewrite the detached evidence.

Rich execution-context evidence is never stringified for identity. It must expose `semanticIdentity`, `executionIdentity`, or `canonicalText`; otherwise projection fails with `DATABASE_CONTEXT_EVIDENCE_IDENTITY_REQUIRED`.

`DatabaseTransactionEvidence~promotionEligible` is false and `DatabaseTransactionEvidenceAdapter~promotionsFrom()` fails with `DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY`.
