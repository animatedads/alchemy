# Codex runbook — FD 00:00–05:00 night campaign, dev8

Codex is a **workload deploy/start operator only**. QueueRexx owns the authority service, Queue Fabric inter-machine wiring, network routes and service lifecycle. Do not create or repair those from this runbook.

Use FD Door Micro Motion v0.2-dev8 with Migratable Job v0.2.5. If the QueueRexx-managed Job-to-Node / remote-start route is not healthy, STOP and report that dependency; never substitute a local allocator or direct worker.

## Fixed campaign inputs

```text
ed209c / TP00003 / 20231010_033544_tp00003.mp4
source sha256 158321e60849bdd1692bf5d2de595538e998845c1d959150dd99097296c84235
wall origin 2023-10-10T03:35:44

ed209d / TP00000 / 20231009_222005_tp00000.mp4
source sha256 b1f9332583f6ceb20424dbc564687688718c48207ca474004c386ac40fddc17
wall origin 2023-10-09T22:20:05

ed209h / TP00001 / 20231010_002359_tp00001.mp4
source sha256 0ea25da2dd4c2cf9d96ed04c1392d332d8335694db0fcc2af399ed6eeaa05cc3
wall origin 2023-10-10T00:23:59

ed209i / TP00002 / 20231010_030155_tp00002.mp4
source sha256 301b519e9894758cb9086b68d0b0691328d172977fd9a95f773eb3ea3ad8ad61
wall origin 2023-10-10T03:01:55
ONLY exclusion: 2023-10-10T03:12:00 <= wall time < 2023-10-10T03:28:00
reason USER_DECLARED_SCENE_OCCLUSION
```

Common analysis window is `[2023-10-10T00:00:00, 2023-10-10T05:00:00)`.

## Per-node preparation

Confirm the exact MP4 is readable and its SHA-256 equals the value above. Confirm no previous direct `run_fd_worker.rex` process owns this partition. Leave all old dev2 state/output untouched.

Use a new workspace:

```bash
ROOT="$HOME/fd_night_migratable_dev8/tp0000X"
STATE="$ROOT/state"
OUT="$ROOT/evidence/tp0000X"
SPEC="$ROOT/launch.tsv"
mkdir -p "$STATE" "$(dirname "$OUT")"

export FD_JOB_ID='FDN-TP0000X'
export FD_PARTITION_ID='tp0000X'
export FD_START_ID='FDNEW-FDN-TP0000X-1'
export FD_SOURCE_NODE_ID='<assigned node>'
export FD_SOURCE_PATH="$SOURCE"
export FD_SOURCE_EVIDENCE_REF="sha256:$(sha256sum "$SOURCE" | awk '{print $1}')"
export FD_OUTPUT_PREFIX="$OUT"
export FD_STATE_DIR="$STATE"
export FD_WALL_CLOCK_ORIGIN='<exact origin above>'
export FD_ANALYSIS_WALL_START='2023-10-10T00:00:00'
export FD_ANALYSIS_WALL_END='2023-10-10T05:00:00'
export FD_PROFILE='FD_NIGHT_F11'
```

For TP00000/1/3:

```bash
export FD_EXCLUSION_COUNT=0
```

For TP00002 only:

```bash
export FD_EXCLUSION_COUNT=1
export FD_EXCLUSION_1_ID='FDX-POLICE-F11'
export FD_EXCLUSION_1_WALL_START='2023-10-10T03:12:00'
export FD_EXCLUSION_1_WALL_END='2023-10-10T03:28:00'
export FD_EXCLUSION_1_REASON='USER_DECLARED_SCENE_OCCLUSION'
```

Create the scientific spec:

```bash
rexx tools/make_fd_window_launch_spec.rex "$SPEC"
```

Require `FD_LAUNCH_SPEC_OK`.

## Start boundary

Hand the prepared workload/spec to the **existing QueueRexx remote managed-placement/start surface**. QueueRexx/Migratable Job must perform:

```text
PLAN -> ALLOCATE -> CHECK -> remote NEW START
                            destination exact lease re-CHECK
                            -> migratable.job.start/1
```

Do not invoke `allocate_fd_managed.rex` on a worker to create independent authority. Do not manually call `run_fd_worker.rex`. Do not fabricate placement fields. Do not alter the `startId` on a retry.

Successful authoritative evidence must identify:

```text
migratable.job.placement/1
migratable.job.remote-start/1    (for remote NEW)
migratable.job.start/1
Migratable Job 0.2.5
native Job-to-Node placement + ownership epoch
```

An exact retry of the same `startId` must replay without a second worker. `START_PENDING_PLACEMENT_HELD` is not permission to launch another copy.

The private worker must have ooRexx POSIX Foundation v0.1-dev1 available.  It will refuse a source that is changing, replaced, truncated, or symlink-retargeted.  Do not disable that guard to force a start; `SOURCE_NOT_STABLE_AT_START` means wait for the source to become stable and retry the same authoritative start semantics as appropriate.

## Scientific post-start checks

Once running, check only workload evidence/state:

- `audio_used=NO`;
- run version `0.2-dev8`;
- wall window/exclusion values are exact;
- F11 acquisition/reacquisition epochs exist;
- relocation/photometric/camera-motion suspensions are recorded rather than converted into negative evidence;
- sample schema is `FD_DOOR_MICRO_SAMPLE_V5`;
- sustained deflection is reported separately from instantaneous door-step response.

Do not alter thresholds during the first night campaign. Harvest the initial visual evidence first.

**ed209e / legacy TP00009 is outside this restart and remains untouched.**
