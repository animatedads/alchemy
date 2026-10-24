# Alchemy NotNotes — Gopher sphere v0.1

**Status: authentic source published; core tests passed; Gopher sphere not yet registered/qualified.**

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
