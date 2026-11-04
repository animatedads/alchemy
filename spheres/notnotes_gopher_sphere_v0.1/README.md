# Alchemy NotNotes — Gopher sphere v0.1

## 29 October 2026 — dev18 current-main integration candidate

The current NotNotes dev18 application candidate from draft PR #77 has been transplanted onto current main rather than merging the stacked historical branch. This makes the already-owned shared DatabaseBackendSelector / RexxSQL provider source available in the exact checkout without vendoring or forking database-owner code.

The integration candidate also carries the proven persisted-field compatibility repair and refreshes dependency provenance to exact Library Single Time Service v0.10 and ConnectSelector dev8. The consumed SingleTime/TZif and base ConnectSelector source files are byte-identical to the older vendored subset; ooRexx r13196 DIRECT DATE/DATETIME regression passes. Remote authenticated routing and live SQLite/WAL remain separate release gates.


## 29 October 2026 — dev17 compatibility repair and current temporal seam

A Project Alchemy v0.5 dogfood reload exposed a persistence compatibility defect in the GitHub dev17 line: legacy field specifications contain a tenth empty reserved slot, while the decoder treated the residual delimiter as hexadecimal ambiguity-policy data and called `x2c(':')`. The repair checkpoint `packages/notnotes_mini_approval_app_v0.1-dev17-compat1` uses bounded slot parsing, accepts the known empty legacy tail, rejects unknown non-empty trailing data, and retains current nine-slot DATE/DATETIME metadata.

Native ooRexx 5.3.0 r13196 reopened the actual v0.5 corpus with 872 documents / 8 user formats. The temporal field test also passes with exact Library Single Time Service v0.10 and ConnectSelector dev8 base selector source. ConnectSelector dev8 confirms the existing `ConnectIntent(operation, REQUEST, IMMEDIATE, AUTO, TIME)` and `selector~execute(intent, params)` contract remains unchanged. Authenticated remote routing remains ConnectSelector/platform-authority scope.

Library dev18 Archive/Compress is a separate patch lineage and must be reconciled explicitly before the next full NotNotes release.


**Status: authentic source published; NotNotes dev17 temporal-authority evidence documented; Gopher sphere registration/validation remains pending.**

## Temporal authority update — 27 October 2026

Mini NotNotes dev16 established DATE/DATETIME validation through Single Time Service and routes zoned resolution through ConnectSelector. Dev17 retains the accepted temporal authority evidence separately from the human field value: temporal kind, canonical value, zone, resolved POSIX instant, tzdb edition and fold/unique resolution where supplied.

NotNotes owns the field and stored evidence, Single Time Service owns civil/timezone interpretation, and ConnectSelector owns provider/transport selection. A renderer, Help Desk or persistence backend must not infer timezone meaning from a displayed local string. Existing evidence may be read after restart without contacting Time Service; any new temporal mutation still requires the Time Service boundary and fails closed when unavailable.

The dev17 static standards gate passed 25 files with 0 errors and 0 warnings. Native dev17 execution is explicitly pending because the r13196 Library package could not be materialised in the current ChatGPT runtime; this sphere does not upgrade that to a runtime-qualified claim.

## Purpose and scope

This is the *core NotNotes platform* sphere, distinct from the Initech TPS Help Desk consumer sphere. It documents NotNotes document authority, semantic application/document projections, saved reports, relationships and lifecycle, dynamic intentions, dependency publication and qualification. The mini application, Alchemy NotNotes domain integration and Help Desk are different components; their source must not be conflated.

## Architecture invariants

1. Authoritative document definitions, documents, revisions, relationships, saved reports, lifecycle and feasibility remain in NotNotes ooRexx objects and persistence.
2. A presentation renderer and a conversational Help Desk are consumers, not duplicate sources of business truth.
3. Applications and specialist services advertise discoverable intentions dynamically. Discovery must be refreshed with context, authority, provider and underlying application changes, never frozen as a startup-time tool list.
4. Recognition of a request, matching its meaning, its current feasibility and permission to execute are distinct. An understood but infeasible action is not an unknown action.
5. The Intention Service may resolve/clarify/propose; it does not acquire NotNotes document mutation authority. LLM recognition fallback does not become dispatch authority.
6. A semantic application projection and semantic document projection are the cross-renderer boundary; UI-specific state must not alter this authority.
7. Dependencies must declare a resolvable version and source path. Never silently rely on a vendored ZIP, a local REXX_PATH, or whichever duplicate class happens to resolve first.
8. Consumer qualification does not qualify omitted platform sources on GitHub.

## Source publication problem (observed 2026-10-24)

GitHub main contains `examples/initech_notnotes_helpdesk_v0.1-dev5/src/InitechHelpDesk.cls` with explicit `::requires "MiniNotesApp.cls"` and `::requires "AlchemyNotNotesIntentions.cls"`, but does **not** contain either required class as repository source. The consumer's `SOURCE_PROVENANCE.md` says the vendored dependency closure is in the accepted delivery ZIP and was deliberately not copied into the source import.

The following are historic candidate source families **to recover and independently verify**, not claims that source has been imported or qualified here:

- `alchemy_notnotes_v0.1-dev14` — Alchemy NotNotes domain/intention runtime; prior delivery records mention a NOTNOTES domain sphere (not a published standalone Gopher sphere).
- `notnotes_mini_approval_app` — Mini NotNotes application, with consumer documentation referring to dev16's semantic projection.
- `notnotes_management_review_dev8_delivery` — TPS/management-review domain fixture.
- `initech_notnotes_helpdesk_v0.1-dev5.zip` — accepted Help Desk consumer, SHA-256 `0448068f18fee165381441e2afb33dbee170f44957f6d3c704ef2948ed42f9c6`; source is under `examples/`, not the full runtime closure.

**Do not reconstruct or fabricate the missing `.cls` sources from this sphere.** Obtain immutable archives, record hashes and source-file SHA-256, inspect exact classes and imports, publish deterministic package roots, run ooRexx 5.3.0 r13196 regression tests, and only then advance implementation claims.

## Related sphere

`spheres/initech_notnotes_helpdesk_gopher_sphere_v0.1` covers the two-tier Initech Help Desk consumer. It does not substitute for this core NotNotes platform sphere.

## Navigation

Read `packs/notnotes/00-sphere.json` and its `start_here` articles. See `qualification/STATUS.md` for the explicit non-qualification state.

## Verified source publication — 24 October 2026

The previous missing-source condition was corrected by publishing **141 authentic source, test, dependency-lock and manifest files** to `main`, in `packages/alchemy_notnotes_v0.1-dev15` (31 files) and `packages/notnotes_mini_approval_app_v0.1-dev16` (110 files). The latter retains its version-locked, patched `vendor/notnotes/AlchemyNotNotes.cls`, rather than silently substituting the independent dev15 implementation. Both packages contain `SOURCE_IMPORT_MANIFEST.json` with original archive and member SHA-256 evidence.

The user Library's ooRexx 5.3.0 r13196 was extracted and executed. Retained Help Desk dev5 `tools/run_environment_test.sh`: **exit 0** (full retained-archive suite). Mini's newly published source tree `tools/run_github_source_qualification.sh`: **exit 0** (seven independent core tests). GitHub blob SHA matched the local source for `AlchemyNotNotesIntentions.cls`, `MiniNotesApp.cls`, patched `AlchemyNotNotes.cls`, and `NoSQLServer.cls`.

Pending: registration/validation of this Gopher sphere, entire clean-checkout Help Desk integration, the omitted historical management-review data fixture, native binaries, and general package-registry resolution. Do not claim the full platform or sphere is runtime qualified.
