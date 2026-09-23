# FD Door Micro Motion v0.2-dev8

Visual-only F11 door micro-motion analysis for FD CCTV, with camera-relocation reacquisition, fixed-structure controls, night-IR hardening, and migration-safe evidence.

## Video/source integrity added in dev8

Production workers now bind **ooRexx POSIX Foundation `oorexx.posix/0.1`** through its coherent stat/lstat gap provider. Before FFmpeg opens the source, the worker requires an unchanged coherent `(device,inode,size,mtime,ctime)` observation across a quiet window; it rechecks immediately after decoder open, periodically while decoding, before a migration checkpoint, and before declaring the run complete. A source that is still growing, truncated, replaced, or a symlink that is retargeted causes a fail-closed non-OK run (`SOURCE_NOT_STABLE_AT_START`, `SOURCE_MUTATED`, or `SOURCE_STAT_FAILED`). Device/inode identity is local provenance only; the existing `source_evidence_ref` remains cross-node content authority.

This directly prevents visual evidence from being emitted across a changing video file and does not use filename timestamps or audio. A failed source-stability preflight is recorded in `state/source.guard.failure.tsv`; it does not overwrite an existing scientific `.run.tsv` during a failed resume.

## What is new in dev7

Dev7 adds a second, slower visual timescale so the analyser does not depend only on frame-to-frame impulses.

The existing impulse path still measures coherent short mechanical response from door edges relative to independent frame/masonry references. Dev7 additionally maintains a **slow relative door-gap baseline** across the upper, lower and bottom door/frame probes. A gradual or sustained leaf displacement can therefore become evidence even when each individual frame-to-frame step is below the impulse threshold.

The temporal model is deliberately conservative:

- it works on `door_x - frame_x`, so common camera translation cancels;
- at least two valid door/frame probe pairs are required;
- excessive cross-height gap spread fails the sustained candidate;
- baseline learning occurs only during quiet visual periods;
- baseline learning freezes around active displacement so motion is not normalised away;
- return toward baseline clears the sustained candidate;
- relocation, exclusion and reacquisition reset/reseed the temporal model;
- complete temporal state is checkpointed and restored across migration.

New observable event class: `FD_DOOR_SUSTAINED_DEFLECTION`. It is still an observation of visual mechanical response, not a causal label.

Dev7 retains the video hardening introduced on the dev6 working line: multi-confirmation night-IR fingerprint acquisition, three-height door/frame tracking, shear fail-closed geometry, broad-field camera-motion rejection, photometric/IR exposure-transition suspension, clipped gradients and sub-pixel edge localisation.

Evidence remains **visual only** (`audio_used=NO`). Audio is not consulted when creating the visual event stream.

## Evidence schemas

- sample: `FD_DOOR_MICRO_SAMPLE_V5`
- event: `FD_VISUAL_MECHANICAL_EVENT_V4`
- run: `FD_DOOR_MICRO_RUN_V7`
- migration bundle: `FD_MIGRATION_BUNDLE_V3`
- compact config: `FDDMM7`

Sample evidence now carries `door_gap_px`, `door_baseline_px`, `door_deflection_px`, `door_gap_spread_px`, and `sustained_door_candidate`. Event evidence distinguishes the peak instantaneous door step from the peak sustained door deflection.

## Runtime / migration boundary

Dev8 retains the **Migratable Job v0.2.5** boundary introduced in dev7:

- `migratable.job/0.2`
- `migratable.job.start/1`
- `migratable.job.placement/1`
- `migratable.job.remote-start/1`

Job-to-Node v0.6 remains placement authority. For the fleet deployment, QueueRexx owns the central Job-to-Node network authority, Queue Fabric routes, access policy and inter-machine wiring. FD does **not** create that infrastructure and has no local-authority fallback.

Migratable Job v0.2.5 removes the remaining initial-remote-start gap: after authoritative placement, `MigratableJobQueuePlacedStartExecutor` can dispatch the standard NEW starter to the chosen node; the destination re-verifies the exact Job-to-Node lease immediately before entering `migratable.job.start/1`. Exact remote-start replay is durable and conflicting reuse of the same `startId` fails closed.

`run_fd_worker.rex` is private payload machinery and may not be used as a fresh authoritative launch path.

## Night campaign

`profiles/FD_20231010_0000_0500.tsv` describes the four-file 00:00–05:00 camera-wall-time campaign. The user-declared scene-occlusion interval belongs only to TP00002: wall 03:12–03:28, media `[605000,1565000)` ms. TP00000/1/3 have no such exclusion.

Intervals where F11 is excluded, relocating, photometrically unstable, or cannot be reacquired confidently are **unavailable visual authority**, never negative door evidence.
