# Semantic Source Control Gopher Sphere v0.1-dev4

This sphere teaches an LLM how to use LLM Gopher around ooRexx Semantic Source Control.

Core rule: **Gopher is the bounded operational interface; SSC is the historical/semantic authority.**

The sphere deliberately does not fake executable SSC capabilities. `ssc.interface` records the planned bounded adapter surface until Gopher installs a dedicated implementation.

## dev2: the store write authority exists

The Semantic Source Store (`packages/oorexx_semantic_source_store`) now has the component its design always required and never had: a write authority. Read `ssc.store-authority` before importing or accepting, `ssc.backend-constraints` before touching the database, and `ssc.mcp-operations` before wiring a transport.

Evidence is LOCAL_PASS (ooRexx 5.3.0 r13196, NoSQLServer v0.79, Crypto v0.8.3 with Foreign Runtime v0.22.6). No MCP host is wired yet, so live MCP SSC state is UNKNOWN.


## 2026-10-23 continuation: semantic mutation authority

The real repository authority introduced in Semantic Source Store dev26 remains the
accepted local evidence base. The next candidate, dev28, adds exact-base semantic
mutation without reintroducing file-oriented editing.

`source.propose_edit` targets one existing semantic object and one exact base revision.
Whole `SOURCE_UNIT` / `SOURCE_FILE` replacement is rejected on this path. A normal edit
creates a proposed immutable revision and leaves acceptance explicit. A stale-base edit
does not overwrite current state: both candidates are retained and the existing sparse
branch service creates a `CONFLICT` branch.

The native ooRexx Source Editor remains projection tooling. It does not become semantic
revision authority; Semantic Source Store / Development Desk owns semantic identity,
revision, conflict and materialisation decisions.

Evidence for the new dev28 mutation increment is CANDIDATE_UNQUALIFIED until the real
database live suite is executed under ooRexx 5.3.0 r13196. The previously recorded dev26
repository round-trip/MCP LOCAL_PASS evidence is not promoted to cover this new code.

Known boundaries remain explicit:
- no live MCP/HTTPS host wiring to SemanticSourceMcpOperations has been proven;
- the earlier dev27 instrumentation/federation work must be rebased and qualified on the
  real dev26/dev28 repository authority before it is called current;
- Gopher source.semantic.* adapter capabilities remain planned rather than inferred.


## 2026-10-29 continuation: dev29 real-authority federation/observability rebase

Semantic Source Store dev29 rebases the previously separate intention-federation and
instrumentation work onto the real dev28 repository/mutation authority. The package resolver
keeps provider-owned PostgreSQL bulk results, removes the residual resource N+1 path, and
emits bounded query/package evidence through an optional Instrumentation Mesh observer.

The Code Examiner may discover specialist intention surfaces through Management Intention
Discovery; discovery is advisory and execution still returns through the secure Examiner
authorization/step-up boundary.

Architecture Intentions v0.1-dev11 was inspected as part of this continuation. It correctly
treats SSC as an independent verifier of architecture handoff receipts and dependency closure;
SSC does not inherit architecture promotion authority.

Evidence is STATIC_CONTRACT_PASS for dev29 in this commit. Live ooRexx r13196, PostgreSQL,
authenticated MCP/HTTPS and browser-route qualification are still required.
