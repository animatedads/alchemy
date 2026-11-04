# Changelog

## 0.1-dev4 — 2026-10-29

- Rebases intention federation and bounded instrumentation onto the real dev28 repository/mutation authority.
- Removes the residual resource-materialisation N+1 path.
- Records Architecture Intentions v0.1-dev11 as an external design authority; SSC remains the independent source/closure verifier.
- Evidence for dev29 is STATIC_CONTRACT_PASS only; live r13196/PostgreSQL/MCP qualification remains open.


## 0.1-dev3 — 2026-10-23

- Records the real dev26 repository authority as the prerequisite base for all later SSC work.
- Adds the dev28 candidate semantic mutation contract: exact-base object edits, explicit
  PROPOSED revisions, no implicit acceptance, and automatic sparse CONFLICT branches on
  stale bases.
- Records whole SOURCE_UNIT/SOURCE_FILE edit rejection as an invariant.
- Records Source Editor as conventional projection tooling, not semantic authority.
- Keeps new mutation evidence CANDIDATE_UNQUALIFIED pending the real r13196/database suite.
- Keeps live MCP-host wiring and the dev27 instrumentation/federation rebase as explicit
  missing work.

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
