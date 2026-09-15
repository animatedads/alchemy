# Accounting Core Gopher sphere v0.1

A durable LLM-facing architecture sphere for Accounting Core.

This sphere answers the questions an LLM should settle **before** writing accounting code or journal entries:

- whose legal-entity books are affected;
- which operational authority proves what happened;
- which exact executable accounting policy determines treatment;
- how establishment, tax registration/election, regulator, client money and reporting scope remain independent;
- why tax determination, tax rounding and settlement rounding are separate;
- how external filed accounts remain assessment evidence rather than native GL truth; and
- how sealed reports, attestations, submissions, corrections and regulator workflow remain immutable evidence.

It is grounded in `accounting_core_v0.10.zip` and is intentionally complementary to the separate `accounting-rigour` sphere. The latter concentrates incident-derived implementation hazards such as DIGITS 50 guard ordering, JSON numeric coercion, replay conflict semantics and omitted-never-zero discipline.

Start with:

```sh
gopher --profile accounting-core context accounting-core --full
gopher --profile accounting-core open ops.accounting-core.reasoning-routine
gopher --profile accounting-core lookup topic=tax-registration --sphere accounting-core
gopher --profile accounting-core search rehypothecation --sphere accounting-core
```

The sphere contains architecture articles and searchable corpora only. It deliberately defines no mechanical language rules: questions such as legal substance, tax nexus, regulatory scope and accounting treatment are semantic judgements whose authority belongs to evidence and policy, not regex detection.
