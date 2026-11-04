# ooRexx Font Manager — engineering sphere v0.2

This sphere documents the work through `oorexx_font_manager_v0.1-dev4` and `oorexx_pdf_v0.1-dev6`.

## Authority

`FontManager` is a renderer-neutral service. PDF, Wire UI, HTML/web output and application packagers consume it. They do not become font discovery, metrics or packaging authorities.

Semantic purpose selection (`BODY`, `HEADING`, `TABLE`, `UI`, `UI_COMPACT`, `CODE`, `PRINT_BODY`, `WEB_BODY`, `ACCESSIBLE_UI`) is distinct from glyph coverage. dev3 adds coverage-aware `FontRunPlan` output so mixed-script consumers can use an ordered set of faces with explicit missing-character evidence.

## Important boundary

Coverage and fallback are **not shaping**. Complex-script shaping, bidirectional reordering, grapheme clustering and OpenType GSUB/GPOS remain future shaping-service work. A renderer must not infer that a non-zero glyph ID is sufficient to render every writing system correctly.

## Current consumer proof

PDF dev5 proves the architecture by using FontManager for semantic selection, subsetting and metrics while retaining PDF-only responsibilities such as Type0/CIDFont construction, `/CIDToGIDMap` and `/ToUnicode`. The legacy Helvetica path remains available without a manager.

## Provenance anchors

- `oorexx_font_manager_v0.1-dev3.zip` — SHA-256 `a5b9bbe38a3e619f0c9cd8b2a15bcb42e3623ca535117b7f232ab91602748838`
- `oorexx_pdf_v0.1-dev5.zip` — SHA-256 `4053ddea12178bea122f281f655984be15141d13656a8ad31113ab1ac17e3ae1`

## 2026-10-29 continuation

PDF now consumes `FontRunPlan` concretely through `PdfManagedFontSet`. The report corpus is planned once and mapped to multiple embedded TrueType subsets. The PDF emitter explicitly requires TrueType because it emits CIDFontType2; CFF/OpenType is not mislabeled. Font Manager dev4 adds an optional hard format constraint and preserves TTC/OTC face indices through discovery and pyftsubset packaging.
