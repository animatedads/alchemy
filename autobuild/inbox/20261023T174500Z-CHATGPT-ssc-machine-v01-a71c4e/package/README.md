# ooRexx Semantic Source Control Machine Protocol v0.1-dev1

A read-only machine projection over the accepted **Semantic Source Control v0.2.3** engine.

API: `semantic.source.control.machine/0.1`.

This package exists so LLM Gopher and other bounded tools can consume SSC without scraping human CLI text and without acquiring acceptance authority. It vendors the exact sealed SSC v0.2.3 implementation for reproducibility; the vendored files are byte-identical to the accepted package and are not an independently modified semantic engine.

Commands: `status`, `identify`, `compare`, `impact`, `source`, `proposals`.

Semantic negative results such as `NOT_FOUND`, `UNCHANGED`, `REVIEW_REQUIRED` and `AMBIGUOUS` are successful observations with `tool_status=OK`.

This cut is read-only. It does not expose baseline acceptance, external-operation proposal decisions, repository mutation, export, or arbitrary `osc` execution.
