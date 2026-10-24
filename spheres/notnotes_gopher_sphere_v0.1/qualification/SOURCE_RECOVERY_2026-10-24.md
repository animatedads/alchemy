# Verified NotNotes source recovery — 2026-10-24

This document is an **archive/source audit**, not runtime qualification and not a claim that the source tree is complete.

## Confirmed Library archives and source members

- `alchemy_notnotes_v0.1-dev15.zip`: SHA-256 `57a7d1b09234621f20c9de5dda312b4e38140b57cb87c45f7318e59730db4488`. Contains `alchemy_notnotes_v0.1-dev15/src/AlchemyNotNotesIntentions.cls`, 19,423 bytes, SHA-256 `11056f3b853e32b9efe5de11adea4902fb85b88775a75224ad864dea6ba97442`; also contains `AlchemyNotNotes.cls`, `AlchemyNotNotesClustered.cls`, tests, `DEPENDENCY_LOCK.json`, and qualification documents.
- `initech_notnotes_helpdesk_v0.1-dev5.zip`: SHA-256 `0448068f18fee165381441e2afb33dbee170f44957f6d3c704ef2948ed42f9c6`. Its `deps/notnotes_intentions/AlchemyNotNotesIntentions.cls` is byte-for-byte identical to the dev15 source member above.
- The same Help Desk archive contains Mini NotNotes v0.1-dev16 at `deps/notnotes_app/`, including `src/MiniNotesApp.cls` (81,144 bytes, SHA-256 `575c5ee7745c5fddb169a3b720488c08ec63a7b47878c1c31d37c12779083d14`), `src/MiniNotesPersistence.cls`, semantic UI/telemetry/time adapter sources, tests and `DEPENDENCY_LOCK.json`.

## Grounded implementation details from the recovered class

`AlchemyNotNotesIntentionRuntime` is the public runtime class in `AlchemyNotNotesIntentions.cls`. Its initialization registers two buckets: `NOTNOTES_READ` (FLEXIBLE) and `NOTNOTES_WRITE` (EXPLICIT). It calls `IntentionService~registerSphere("NOTNOTES", ...)` and registers five canonical operation names: `show documents`, `show views`, `show fields`, `set field`, and `refer document`. Write registrations require named slots and use plan assessors. The runtime's `NOTNOTES` Intention Service domain sphere is **not** the same thing as this LLM Gopher continuity sphere.

Mini NotNotes dev16's `MiniNotesApp` creates an `AlchemyNotNotesNode`, maintains document/report/format state, emits semantic projections, supports persistence and accepts optional Instrumentation and Time Service boundaries. Preserve exact method signatures by inspecting the authenticated source rather than inferring a static catalog from the Help Desk.

## Why GitHub main was incomplete

The source import at `examples/initech_notnotes_helpdesk_v0.1-dev5` published consumer code and intentionally did **not** copy its vendored dependency closure into the repository. The Help Desk README describes the Mini NotNotes dev16 runtime, but a clean checkout cannot resolve `MiniNotesApp.cls` or `AlchemyNotNotesIntentions.cls` through committed source roots alone.

The omitted source is **recoverable**; it is not yet **published**. Publishing documentation-only sphere files does not close this gap.

## Publication and qualification gates

1. Import immutable Alchemy NotNotes dev15 and Mini NotNotes dev16 source roots as separate versioned packages. Preserve archive member bytes, tests, manifests, dependency locks and hashes.
2. Audit Mini dev16's locally patched `vendor/notnotes/AlchemyNotNotes.cls` against the separate dev15 package before selecting a compatible dependency version. Do not silently prefer whichever copy is first on `REXX_PATH`.
3. Verify transitive `::requires`, exported public classes, exact dependency versions, native/API requirements, and deterministic package-registry resolution. Do not turn a consumer-vendored implementation into an unpinned platform package.
4. Exclude mutable TPS data, customer records, qualification caches and archive-only external dependencies from a source-only import unless specifically reviewed.
5. Perform fresh ooRexx 5.3.0 r13196 compilation and NotNotes/Intention Service/Mini NotNotes/Help Desk tests from a clean checkout. A historical qualification document is not a current test result.
6. Register/validate the Gopher pack in LLM Gopher and record actual resolution provenance before marking the sphere activated.

**Current outcome:** exact files and hashes located, class contents inspected, equivalence proven; no runtime tests performed during this audit, and source publication remains outstanding.
