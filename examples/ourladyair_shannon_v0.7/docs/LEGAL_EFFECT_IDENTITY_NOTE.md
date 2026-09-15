# Legal Effect identity and compatibility note

Shannon v0.7 deliberately separates three identities:

1. **Loaded Legal Effect engine API/build.** These come from
   `LegalEffectBuild` and are recorded as evidence. The current validated bundle
   reports `legal.effect/0.10` / `0.10`. They are not startup release locks.
2. **Shannon policy generation.** The exact fictional operator-policy bytes are
   SHA-512 verified and compiled by the loaded Legal Effect engine. Successful
   compilation/evaluation is the compatibility gate for the semantics Shannon uses.
3. **HardWorld promotion compatibility contract.** The unmodified
   `LegalEffectV05PromotionAdapter` emits `LEGAL_EFFECT/0.5/...`. That namespace
   identifies the bridge contract and is not relabelled to the engine API.

A current turn can therefore truthfully carry:

```text
legal_api             = legal.effect/0.10
legal_build           = 0.10
legal_generation      = OURLADYAIR-SHANNON-LEGAL-G3
promotion_bridge      = HardWorld LegalEffectV05PromotionAdapter
promotion_authority   = LEGAL_EFFECT/0.5/<generation>@...
```

The current Legal Effect v0.10 line introduces host source-authority attestations
for **live Runtime Registry acquisition**. Shannon's present fictional policy is an
offline/local compiled policy and v0.7 does not claim live trust-profile admission
for that source.

`test_shannon_legal_identity_and_promotion.rex` proves that evaluation alone does
not mutate HardWorld, explicit promotion does, and the resulting facts retain the
exact `LEGAL_EFFECT/0.5/...` bridge identity and rich evidence.
