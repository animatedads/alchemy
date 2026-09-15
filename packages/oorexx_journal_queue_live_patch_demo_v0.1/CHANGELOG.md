# Changelog

## v0.1

- Two-process live-patch demonstration over a shared PERMANENT ooRexx Queue Fabric queue.
- Runner checkpoints pointer-only JournalPointedState state immediately before every X(i).
- Patch payload carries method name, ooRexx Array of source lines, and rewind count.
- Receiver-side LiveMethodPatchable installs the method without restarting the runner.
- State-of-the-Nation restores N iterations while the newly installed code remains live.
- Abandoned journal branches remain reconstructible.
- Repeated patch/rewind/replay cycles validated on supplied ooRexx 5.3.0 r13196.
