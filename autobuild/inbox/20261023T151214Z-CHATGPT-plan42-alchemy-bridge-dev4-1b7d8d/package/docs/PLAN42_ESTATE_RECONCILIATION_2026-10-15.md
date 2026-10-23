# Plan42 in the wider Project Alchemy estate — development handoff 0.1-dev2

**Date:** 15 October 2026  
**Scope:** Estate review, version-pinned candidate, non-authoritative source/compile handoff.  
**Implementation base:** `alchemy_framework(65)` + accepted FOP doc patch + Plan42 integration dev1.  
**Authoritative estate context inspected:** Project Alchemy NotNotes v0.6 working corpus, October 15; nine October Library package heads; October 9 v0.4 registers as prior historical architecture evidence.

## Correction to the dev1 framing

`alchemy_framework(65)` is the *specification framework*, **not** the complete contemporary Project Alchemy platform. Its `runner.rex` container registration is a legitimate local foothold but does not enroll Plan42 with the estate Runtime Registry, Intention Service, Source Store, or plugin router.

The NotNotes v0.6 working corpus reports **34 stacks, 176 components, 215 exact packages, 176 technical papers, 233 evidence records, 66 interactions, and 54 stack memberships**. Its own `qualification/qualification_v06.txt` reports `VERIFY=PASS` after a narrowly scoped persistence-format repair. This does not replace individual runtime acceptance or establish that this candidate was registered there.

## Existing Alchemy authorities and Plan42's boundary

| Estate owner | Inspected package / register | Plan42's permitted role | What must not be assumed |
|---|---|---|---|
| Runtime Registry | v0.14 in v0.4 historical register | discover service capability once an exact binding is approved | `runner.rex` registration is not Runtime Registry publication; immutable generation API has not been verified in current source |
| Runtime Reference | v0.4 in v0.4 register | optional future location of a selected operation | not a substitute for Runtime Registry generation selection |
| Semantic Source Store | dev27, source inspected | consume authoritative source/package/member revision and link compiler evidence back | local filesystem SHA is not an authoritative revision or SSCS commit |
| Coding Intention Steps | dev17, source inspected | optional Plan42 back-end/IR transform of an *accepted* semantic plan | `CodingContext~semanticPlan` is not intrinsically Plan42 JSON; no meaning-changing flattening |
| LLM Coding Workbench | dev13, source inspected | compile/compatibility evidence provider after the governed READY/COMMIT and Development Desk workflow | compiler execution cannot perform model-decided source changes |
| ooRexx Intention Service | dev11, source inspected | declare inspect/compile operations with capability and clarification descriptions | no automatic READY, dispatch, or authorisation |
| Connect Selector | dev5, source inspected | optional direct or RPC `REQUEST` adapter; any durable `ENQUEUE` is a separately specified operation | no fallback after send, no presumed RPC response from Queue Fabric PUT |
| RPC Service Core + Serialization Selector | interfaces referenced by gRPC binding dev3 | explicit future registration of allowed object and methods, protocol encoding separately | no remote reflection/autodiscovery; no protobuf implementation in Plan42 |
| Instrumentation Mesh | dev8, source inspected | optional strictly non-authoritative event/correlation evidence | time proximity never proves causation; an event does not approve a codelet |
| Alchemy Python | dev5, source inspected | an eventual *client* of a published Plan42 service over the existing Python SDK/direct macrospace surface | do not invent a parallel Python transport stack |
| Communications Discovery | dev12, source inspected | optional detached read-only display for compiler/portability findings | detached UI is NO_DISPATCH; no code publication |
| Live class upgrade | `upgrade_v3_practice.rex` proof (conversation) | future reviewed migration plan / compatibility diagnostics | practice proof does not mean the current plugin router can replace arbitrary live objects |

The selection contract must honor the current `ConnectIntent` modes `REQUEST`, `NOTIFY`, `ENQUEUE`, `CALLBACK`, and guarantee requirements. `plan42.inspect` and `plan42.discover` are read-only REQUEST operations. `plan42.compile` is **governed staging** and requires output write authority; remote RPC is only possible after service registration/policy. QUEUE is **not** a synonymous switch for compilation: an asynchronous workflow needs a separate durable work contract and its own acceptance semantics.

## New dev2 executable work

- `estate/plan42.estate.candidate.json`: explicit source-version and acceptance crosswalk with SHA-256 digests of ten inspected Library ZIPs. These are **source evidence**, not active dependencies that the compiler imports.
- `tools/plan42_estate_handoff.py manifest`: displays that candidate.
- `tools/plan42_estate_handoff.py prepare --spec ...`: inspects a local Plan42 spec through the previously tested adapter, then projects a candidate envelope. It does not modify source, generate code, publish a class, or issue messages.
- `tools/plan42_estate_handoff.py prepare --spec ... --receipt ...`: validates an existing *local* successful compiler receipt and its original/current source and staged output SHA. Rejects any receipt claiming execution, dispatch, or publication. This evidence remains `LOCAL_DIGEST_ONLY`.
- `tools/plan42_estate_handoff.py verify-pins --package-dir ...`: verifies the ten inspected Library copies against pinned SHA-256; does not install them.
- `plan42_bridge.py discover` includes a reference to the unpublished estate candidate, without changing the existing three semantic service methods.

Use from Alchemy root:

```bash
python3 tools/plan42_estate_handoff.py manifest
python3 tools/plan42_estate_handoff.py prepare --spec tests/preferred_capabilities_smoke.plan42.json
python3 tools/plan42_estate_handoff.py verify-pins --package-dir /path/to/inspected-library-copy
python3 -m unittest discover -s tests -p 'test_plan42_estate_handoff.py' -v
```

The first handoff is deliberately **not** the format accepted by any current live Semantic Source Store mutation API; it is an informational proposal/receipt that an authorized adapter can consume after exact method/schema confirmation. No renamed classes or duplicated authorities are introduced.

## Acceptance and sequencing

**Static/dev2 acceptance:** package pins verified locally, Python bridge/unit tests, ten focused handoff tests and negative authority guards. **Not established:** current Runtime Registry service publication; Semantic Source Store commit; Coding Intention direct live interoperability; Connect Selector production routing; RPC registration; `CODELET:DEFINE`; model-object hot replacement; Rust live compiler; end-to-end ooRexx integration.

Recommended next integration boundary: acquire the exact current Runtime Registry and Semantic Source Store source contracts, bind the approved `plan42` service to their unchanged registration and immutable source identifiers, then deliver tested Coding Intention dev17 semantic-plan mappings with explicit per-operation loss diagnostics. Only then should codelet/class upgrade follow, with independent authorisation, quiescence, migration and rollback evidence.
