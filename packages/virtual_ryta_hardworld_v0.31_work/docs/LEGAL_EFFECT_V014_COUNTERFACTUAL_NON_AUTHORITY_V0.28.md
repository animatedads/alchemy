# Legal Effect v0.14 counterfactual non-authority boundary

Legal Effect v0.14 exposes deterministic counterfactual/sensitivity analysis. Its public comparison objects explicitly carry `hypothetical=true` and `authoritative=false`; assumptions carry authority `COUNTERFACTUAL_ASSUMPTION`.

RYTA therefore treats the feature as evidence only. `LegalEffectV014CounterfactualEvidenceAdapter` validates that public behavioural surface, hashes Legal Effect's explicit `canonicalText`, preserves stable scalar labels, and retains the native Legal comparison object as provenance. It never constructs `EvidencePromotion`.

The evidence identity intentionally excludes Alchemy object ids, execution telemetry and object stringification. Repeating the same Legal counterfactual through different adapter objects yields the same evidence identity; changing the assumed value changes that identity.

An explicit `promotionsFrom` call raises `LEGAL_COUNTERFACTUAL_NOT_AUTHORITY`, and the projected evidence does not implement the sealed promotion-set surface expected by `EvidencePromotionApplier`.

```text
actual Legal assessment
        |
        +-- live runtime-bound evaluation -----------------> authority path
        |
        +-- counterfactual evaluator
                 | hypothetical / non-authoritative
                 v
          RYTA evidence projection
                 |
                 X no promotion path
```

This boundary is separate from the existing reducer-order guard. Counterfactual analysis does not resolve `LEGAL_STATUS_REDUCTION_AMBIGUOUS` and cannot be used to bypass it.
