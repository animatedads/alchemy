# FD Door Micro Motion v0.2-dev5

Visual-only, per-decoded-frame measurement of F11 door micro-motion and coherent fixed-structure motion in FD CCTV.

v0.2-dev5 rebases the NEW-start path onto **Migratable Job v0.2.4** and its standard managed initial-placement API:

- main API: `migratable.job/0.2`
- starter API: `migratable.job.start/1`
- managed initial placement: `migratable.job.placement/1`
- placement audit evidence: `migratable.job.placement.receipt/1`
- Job-to-Node authority: v0.6 (`job.node.allocator/0.6`), exact core archive SHA-256 `58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead`

The dev4 FD-specific authority receipt is retired from the normal NEW path. Operators no longer type or copy a placement ID or ownership epoch into an FD launch specification. The exact `JobPlacementRequest` is part of `FDDoorMicroMotionStarterApplication~definition()`, the v0.2.4 managed-placement tool asks Job-to-Node to allocate it, `CHECK` re-verifies the native lease, and only then may `START` enter the standard starter.

The authoritative NEW path is therefore:

```text
measured node probe
 -> Job-to-Node v0.6 registry + durable ownership journal
 -> MigratableJobManagedPlacementTool PLAN
 -> ALLOCATE
 -> CHECK exact native JobNode lease
 -> START
 -> migratable.job.start/1
 -> private FD worker
```

A failed or ambiguous START **retains the placement**. The placement may be released only after the operator/coordinator has independently established that no execution is running. This follows Migratable Job v0.2.4 rather than guessing that a failed launcher produced no side effect.

`run_fd_worker.rex` remains private payload machinery. `start_fd_migratable.rex` is retired in dev5; the NEW operator surface is `allocate_fd_managed.rex` followed by `start_fd_managed.rex`.

Scientific behaviour is unchanged from dev4: visual-only (`audio_used=NO`), video PTS is the internal measurement time, camera wall clock selects campaign windows/exclusions, camera relocation suspends measurement authority until F11 is reacquired, door motion is relative to independent frame references, and global/masonry motion requires coherent fixed-structure agreement. Units remain pixels/sub-pixels.

`profiles/FD_20231010_0000_0500.tsv` describes the four-file night campaign. The declared F11 scene-occlusion interval belongs only to TP00002: wall 03:12–03:28, media `[605000,1565000)` ms.

Migration-safe processing remains frame-boundary checkpointed with immutable CSVStream TSV shards and digest-bound bundles. RECOVER and HANDOFF keep their existing Migratable Job authority paths; managed placement is deliberately NEW-only.
