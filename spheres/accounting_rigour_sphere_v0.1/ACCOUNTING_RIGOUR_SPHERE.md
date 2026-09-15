# Accounting Rigour Gopher sphere v0.1

An LLM-focused knowledge sphere for money-accounting code.

It adds only:
- `packs/accounting-rigour/` (sphere manifest, access policy, articles, corpus)
- `profiles/accounting-rigour.json`
- `tests/run_accounting_rigour_sphere.sh`
- Accounting Rigour qualification/manifest files

It does not replace `engine/gopher.py`, and it layers `packs/core + packs/accounting-rigour` rather than re-defining engine services.

Start with:

    ./gopher --profile accounting-rigour context accounting-rigour
    ./gopher --profile accounting-rigour help accounting-rigour --text
    ./gopher --profile accounting-rigour open accounting-rigour.precision.minor-units-50-digits --sphere accounting-rigour
    ./gopher --profile accounting-rigour search 'settlement rounding' --sphere accounting-rigour
    ./gopher --profile accounting-rigour lookup topic=rounding --sphere accounting-rigour

Design discipline: every entry is grounded in Accounting Core v0.2..v0.10 contracts
and the v0.3.1/0.4.1 and real-filing qualifications. Where detection needs arithmetic
context, legal intent, or durable store state, the guidance is an article or a corpus
record, not a forced syntactic rule. This sphere intentionally ships no language-rules,
because the money failures are semantic, not reliably mechanical.

Qualification (data-only, no ooRexx .deb required):

    ./tests/run_accounting_rigour_sphere.sh

Observed baseline: `accounting_core_v0.10.zip`. Verify a newer local version before use.
