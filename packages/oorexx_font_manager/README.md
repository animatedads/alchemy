# ooRexx Font Manager v0.1-dev2

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
