# Changelog

## v0.1 — 2026-08-25

- Added `JournalPointedState`, a branching reversible journal over a live ooRexx `Directory`.
- Added pointer-only `JournalPoint` checkpoints and retained common-ancestor branch switching.
- Added batched `JournalEdit` changes so one meaningful event can create one journal node.
- Added non-mutating reconstruction and branch-to-branch diff planning without persistent full snapshots.
- Added `StateOfNationController` with manual, any-change, and fixed-event checkpoint policies.
- Added progress publication and `StateProgressWatcher` for second-activity stall observation.
- Added `LiveMethodPatchable` and `LiveStateRecoveryCoordinator` for receiver-authorised live method insertion followed by exact state rewind.
- Preserved failed speculative futures as inspectable branches while repaired retries fork from the same checkpoint.
