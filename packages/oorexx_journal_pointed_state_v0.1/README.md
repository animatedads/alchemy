# ooRexx Journal Pointed State v0.1

A branching, diff-backed state primitive and State-of-the-Nation controller for live ooRexx testbeds.

Core classes are in `src/JournalPointedState.cls`:

- `JournalPointedState` — current data plus reversible branching journal;
- `JournalEdit` — batched atomic edit builder;
- `JournalPoint` / `JournalChangeNode` / `JournalDelta` — history primitives;
- `StateOfNationController` — global pointer-only checkpoints and restore;
- `LiveStateRecoveryCoordinator` — front-end-driven live object method insertion followed by state rewind;
- `StateProgressWatcher` — cheap second-activity progress/stall observation.

See `docs/DESIGN.md` and `examples/emulator_repair_loop.rex`.
