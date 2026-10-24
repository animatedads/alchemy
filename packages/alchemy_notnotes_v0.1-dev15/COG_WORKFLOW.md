# Cog workflow — dev12

Alchemy Cog remains the release execution ledger for NotNotes development: natural-language request -> deterministic proposal -> CogLLM review -> frozen plan -> execution -> retained evidence.

During the handover session the project-coordination MCP endpoint was unavailable, so Library evidence was used to recover the current dev11 head and prior COG state. The local `cog.py`, `cogllm.py`, learned recipe library and plan ledger were then recovered from Library and qualification returned to the COG workflow.

The first full dev12 COG regression (`PLAN0048`) failed because the execution environment omitted the r13196 runtime `bin` directory containing `json.cls` from `REXX_PATH`. That failed experiment remains in COG history. The corrected pre-standards regression was `PLAN0049`; after standards-driven source repairs the final full regression is `PLAN0057`, which ran eleven tests with zero failures.

Dev12 reuses the existing deterministic runtime-test, multi-file writer, deterministic ZIP, ZIP-integrity, SHA-256 and strict ooRexx standards recipes. Packaging and release evidence are produced through those recipes.

## Dev14 continuation

Dev14 reuses COG as the execution ledger. `PLAN0005` records the first failed full regression caused by the inherited dev13 test runner assuming the product root as its current directory. The runner was corrected to establish its own root. `PLAN0006` then completed all twelve tests with zero failures, including the provider-neutral Intention Service integration probe. Standards and final sealing plans are recorded in the qualification bundle.
