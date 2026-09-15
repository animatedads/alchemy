# Journal-pointed state design

## Purpose

`JournalPointedState` is a compact, reconstructible internal-state primitive for ooRexx testbeds and emulators. It keeps one mutable current data set plus a branching journal of edits. A checkpoint is a pointer into that journal, not a complete copy of the data.

The primary recovery loop is:

1. State-of-the-Nation controller checkpoints immediately before an instruction/event.
2. The emulator attempts the instruction.
3. A missing or faulty operation stalls execution after speculative state changes.
4. A front-end object receives a structured `StateRecoveryRequest`.
5. The front end (human, rule engine, or AI-backed object) supplies ooRexx method source.
6. The method is installed on the live target object with `setMethod`.
7. The controller restores all registered journalled components to the pre-instruction checkpoint.
8. The same instruction is retried. No emulator restart is required.

Code and machine state intentionally live on separate timelines: state is rolled back; the newly installed method remains.

## Storage model

A `JournalPointedState` owns:

- one current `Directory` holding the live values;
- a retained set of `JournalChangeNode` objects;
- one current-head node id.

Each change node stores its parent pointer and only the keys changed by that edit. Each delta carries old existence/value and new existence/value so it can be applied in either direction.

There is no full snapshot per checkpoint. `snapshot` and `reconstruct` materialise a full `Directory` only when explicitly requested by a caller.

## Branching history

Rewinding does not delete the old future. A new mutation after rewind creates a new child of the restored node. Switching between arbitrary retained points finds their common ancestor, applies reverse deltas to that ancestor, then applies forward deltas along the target branch.

This is important for testbeds: the failed speculative execution remains available for inspection while the repaired execution proceeds from the exact same pre-fault state.

## Batched edits

`beginEdit` / `JournalEdit` groups many key changes into one journal node. Emulator memory code should use a batch for naturally atomic operations such as a multi-byte store or one instruction's related state changes. This keeps journal overhead proportional to meaningful change events rather than individual helper calls.

## State-of-the-Nation controller

`StateOfNationController` registers journal participants and maintains their latest pointers. Its checkpoint contains only component ids and `JournalPoint` objects plus event metadata.

Policies in v0.1:

- `MANUAL` — explicit checkpoints only;
- `ANY_CHANGE` — checkpoint after any registered participant change;
- `EVENT` / `FIXED_EVENT` — checkpoint on a named event reported with `noteEvent`.

The controller preflights all participant points before a restore so an invalid checkpoint is rejected before any component is moved.

## Progress watching

`noteProgress` publishes a cheap generation token and context. A second ooRexx activity can poll it through `StateProgressWatcher`; repeated unchanged generations identify a stall without taking ownership of the emulator. The actual recovery request can then be routed through `LiveStateRecoveryCoordinator`.

## Value ownership rule

Journal values should be immutable values or copy-on-write objects. The journal records object references, not deep serialised copies. Mutating an object in place after storing it would also mutate the historical reference. Emulator bytes, integers, immutable strings, and replacement-style state objects satisfy the intended contract.

## Durability boundary

This package is an in-process execution/history primitive. Existing explicit emulator `state` / `restoreState` or freeze-file formats remain the durable/export boundary. A durable freeze can be taken from any reconstructed journal point when required.
