# ooRexx Font Manager v0.1-dev3

Renderer-neutral font discovery, matching, purpose selection and packaging for ooRexx applications.

The Font Manager is deliberately independent of PDF, Wire UI, browsers and any particular renderer. Clients request a font by properties or purpose; providers discover concrete fonts; transformers package/subset them when required.

## Core objects

- `FontManager` — central registry, provider coordinator, purpose resolver and packaging broker.
- `FontFace` — concrete face identity and metadata.
- `FontQuery` / `FontMatch` — renderer-neutral matching request/result.
- `FontPurposeProfile` — policy for semantic purposes such as BODY, HEADING, TABLE, UI, CODE, PRINT_BODY and WEB_BODY.
- `FontPackageRequest` / `FontPackageResult` — transformation/subsetting boundary.
- `FontManifestProvider` — deterministic application/package supplied faces.
- `FontconfigProvider` — Linux/Unix discovery and native matching through fontconfig.
- `FontToolsMetricsProvider` — optional exact SFNT advance/ascender/descender metrics through the central manager.
- `PyftsubsetTransformer` — optional fontTools backend for glyph subsetting and WOFF/WOFF2 packaging.
- `FontIntentions` — Intention Service profile for find/list/register/package/subset/measure font operations.

No font files are distributed by this package. Font licensing and embedding permission remain properties of the selected face/deployment and must be checked before redistribution.

## dev2 additions

- `FontGlyph` and `FontGlyphPlan` provide renderer-neutral Unicode-to-glyph identity, advances and SFNT geometry.
- `FontToolsGlyphProvider` inspects a face once and returns units-per-em, ascent/descent, bounding box, PostScript name, glyph IDs and advances for a requested text corpus.
- `FontGlyphPlan~measure(text,size)` answers repeated width requests in-process from the inspected advances, avoiding one external backend process per layout probe.
- `PyftsubsetTransformer` now supplies subset corpora through `--text-file` rather than command-line text, avoiding quoting, locale and command-length corruption on realistic multilingual application corpora.
- Unicode subset qualification covers Latin diacritics, punctuation/currency, Greek and Cyrillic.

The glyph plan is deliberately renderer-neutral. PDF may use it to construct CID mappings; UI and web renderers can use the same central identity/metrics service without acquiring PDF semantics.

## GitHub source layout

The release archive contains a vendored Intention Service snapshot for standalone qualification. In the Alchemy GitHub source tree that dependency is intentionally omitted; `tools/run_environment_test.sh` resolves the independently published sibling `packages/oorexx_intention_service` package instead. Set `INTENTION_SERVICE_ROOT` to override that location.


## dev3 — coverage-aware fallback and font runs

Font selection can now return a **run plan** rather than forcing one face to cover an entire string. `FontManager~planRunsForPurpose(purpose,text[,maxFamilies[,language]])` starts with the normal semantic-purpose match, records actual glyph coverage through `FontGlyphPlan`, then asks registered coverage providers for faces covering still-missing Unicode scalars.

- `FontRun` binds one contiguous UTF-8 text run to the selected `FontFace` and glyph plan.
- `FontRunPlan` returns the ordered runs, the minimal face set actually used, and an explicit `missing` array. `fullyCovered` is false rather than silently substituting glyph 0.
- `matches(query)` exposes deterministic ranked candidates.
- `fallbackMatches(query)` collapses those candidates by family so a machine with many weights/width variants does not waste fallback work on near-identical faces.
- `registerCoverageProvider(provider)` is a renderer-neutral acceleration seam. The Fontconfig provider implements `findCovering(query,codepoint[,language])` using host charset/language knowledge.
- When no coverage-aware provider exists, the manager falls back to generic family-ranked glyph inspection, preserving portability.

The live qualification uses `TPS café — 日本語 — Ω ∑`. On the qualification host it resolves Noto Serif as the primary print face and Noto Sans CJK JP as the fallback, yielding four ordered runs with zero missing glyphs.

This is **coverage and run segmentation, not complex-script shaping**. Arabic/Indic shaping, bidi ordering and OpenType feature application remain a separate shaping-service boundary rather than being guessed inside Font Manager.
