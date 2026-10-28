# Physics World Gopher Sphere v0.1

## Authority
Physics World owns physical behaviour and physical evidence. It does not own CAD/CAM
design truth, reusable Parts identity, Materials truth, electrical behaviour, Audio
interpretation, Photo World survey authority, or investigative event labels.

The canonical executable source is `packages/oorexx_physics_world`. This sphere is
continuity/retrieval authority; it does not fork executable Physics source.

## Current baseline
GitHub canonical head observed 2026-10-24 was Physics World 0.1-dev50. Dev50 extends the
generic acoustic experiment with Room-F refinement/evidence over existing Cluster object
transport. Physics still does not know which location an investigator hopes to prove.

Dev50.1 records the first post-review object-semantics repair: `+0` is not numeric
coercion in ooRexx; it is operator-message dispatch.

## Stable decisions
- PhysicalWorld is the shared spatial authority; solvers do not create competing scene graphs.
- Maths owns generic numerical algorithms; Physics owns physical state, topology and interpretation.
- Units owns dimensions, quantities and conversions.
- Freeze/replay captures future-determining continuation state. In-memory checkpoints are world/body bound and restore transactionally.
- Journal Pointed State is the shared durable/replay architecture; Physics does not invent an incompatible State-of-the-Nation authority.
- AcousticImpulseResponse is a generic forward acoustic oracle. Audio independently matches observations.
- Guitar monitor feedback is physical: speaker -> field -> all strings/body -> pickup. Unplayed means zero intentional excitation, not zero possible motion.
- Physics never invents catalogue coefficients, aerodynamic data, tyre laws, room materials, damage factors or localisation answers.

## Review and standards
Portfolio findings PHYS-001/PHYS-002 are repaired in canonical source. The 2026-09-27
standards report is not a clean bill of health: inherited PLUS_ZERO, short-circuit,
SIGNAL and loop findings remain open until individually repaired and requalified.

## 2026-10-27 reconciliation and pending qualification
Authenticated Rasen Falcon lane: `oorexx-physics-world` (not the `wire_ui_windows` example). GitHub canonical package `packages/oorexx_physics_world/VERSION.txt` reads `0.1-dev50.1`; earlier dev46.9 archives are historical and must not overwrite this head.

The 2026-09-27 review identified PHYS-001/PHYS-002; canonical sphere records their repair. Standards-enforcer findings remain an OPEN qualification gate; a `+ 0` expression invokes ooRexx `+` message dispatch and may mutate a user object, so no mechanical replacement with `* 1` or other operator coercion is admissible. Each site needs semantic validation and adversarial object regression. `&` does not short-circuit; audit each potentially unsafe operand before converting to nested conditionals.

Freeze/replay compatibility must include behavioural authority (dynamic `setMethod`, class `define` where permitted) and pending delayed messages, in addition to state variables. A journal-pointed checkpoint cannot promise deterministic continuation if those future-determining elements are omitted. No new incompatible checkpoint format is authorized by this note.

**Open implementation:** run the enforcer directly against the canonical dev50.1 source/package; classify findings, repair in bounded batches, execute r13196 tests, and record exact PASS/FAIL/SKIP receipts. This sphere update is a coordination/documentation commit, **not** a claim that source repairs or full-suite qualification were performed in this turn.


## 2026-10-28 — dev50.2 journal preflight implementation
Canonical source now includes the bounded journal restore repair at `packages/oorexx_physics_world/rexx/PhysicsJournalState.cls`.
The shared State-of-the-Nation `journalCanMoveTo` preflight reconstructs the requested point with Journal Pointed State v0.1 and asks any participant supporting `validateContinuationState` to validate its physical continuation before the journal pointer moves. Physics' core participant now binds the continuation to its originating world and exact ordered body inventory, and validates these constraints on direct restore too. The checkpoint core schema is `physics.world.core/0.2`; this changes the live-core payload shape and must not be silently interpreted as 0.1.

Regression source: `packages/oorexx_physics_world/tests/test_physics_journal_preflight.rex` exercises a foreign-world state inserted into a journal, and a changed body inventory, and asserts that rejected moves do not change pointer, pose or time.

**Qualification distinction:** source, regression fixture and sphere are committed; a 2026-10-28 interpreter execution receipt is not available in the present execution environment. JPS `stateAt` is a reconstructing read, not a pointer move. Non-core participants without `validateContinuationState` still rely on existing restore/rollback behaviour; universal behavioural-authority or pending-event capture is **not claimed**. The package-wide standards-enforcer gate and the full suite remain open.
