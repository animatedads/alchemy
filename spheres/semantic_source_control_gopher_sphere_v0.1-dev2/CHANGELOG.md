# Changelog

## 0.1-dev2 (2026-10-23)

Written by Claude (Opus 5.5). Architecture: Tom Dyer.

- Adds `ssc.store-authority`: the Semantic Source Store now has a write authority (`SemanticSourceRepositoryService`). It is method-granular, keeps SOURCE_UNIT layouts and immutable per-import projections, makes acceptance explicit and authorized, and refuses altered bytes.
- Adds `ssc.backend-constraints`: what the `test/NoSQLServer.cls` stub hid. It covers the NoSQLServer v0.79 UPDATE literal evaluation, missing IN lists, qualified join keys and CRLF rewriting; Foreign Runtime crypto; and the RESULT-variable trap.
- Adds `ssc.mcp-operations`: the eleven implemented store operations, with the principal taken from the session and never from the request.
- `ssc.interface` gains `store-operation` records marked `IMPLEMENTED_LOCAL` (LOCAL_PASS; no MCP host wired). Gopher `source.semantic.*` capabilities stay `PLANNED`: no Gopher adapter exists.

## 0.1-dev1

- Initial Semantic Source Control Gopher sphere.
- Establishes the boundary: Gopher is the bounded operational interface; SSC is the historical semantic authority.
- Inherits existing ooRexx source examination/edit/rules/test/package capabilities.
- Publishes SSC identity, workflow, acceptance, external-operation, live-repair and adapter-contract guidance.
- Publishes a typed `ssc.interface` corpus with planned SSC adapter capabilities and Gopher status mappings.
- Deliberately does not publish fake executable SSC capabilities before a dedicated adapter exists.

## 0.1-dev2 — 2026-10-24 database provider isolation clarification

- Records `DatabaseBackendSelector` as the sole runtime provider-package selection boundary for SSC.
- Requires provider choice to be configuration-only; backend changes must not depend on Codex/model edits to source or `::requires` directives.
- Records the ooRexx class-name collision constraint: NoSQLServer and Database Core have overlapping public database class names with different semantics, so neutral SSC code must not load both class sets.
- Records package isolation: only the selected provider package is loaded; PostgreSQL may load Database Core inside its provider package, while NoSQLServer returns its namespaced Database Core compatibility facade.
- Retains the historical NoSQLServer v0.79 qualification caveats separately from the current composition rule.
