# Deployment — FD Door Micro Motion v0.2-dev8

Runtime baseline: ooRexx POSIX Foundation v0.1-dev1 (`oorexx.posix/0.1`, coherent gap provider) plus  ooRexx 5.3.0 r13196; stock `csvStream.cls`; Foreign Runtime v0.22.6 with host-local FFmpeg ABI 61/59; Migratable Job v0.2.5 (`migratable.job/0.2`, `migratable.job.start/1`, `migratable.job.placement/1`, `migratable.job.remote-start/1`); Job-to-Node v0.6; Crypto v0.8.3; Runtime Reference v0.4.


Exact development baselines used for this release:

- Migratable Job v0.2.5 archive SHA-256 `e44cf0c4894917ba773222408631ed3d7bd6c88aa4e5a4fa61f3c4243206d72f`;
- ooRexx POSIX Foundation v0.1-dev1 archive SHA-256 `7d13f10268b0801caeec5482601aa3af21af8f9139a553bef8a99275a7591d29`;
- Job-to-Node v0.6 core archive SHA-256 `58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead`;
- Job-to-Node network1 archive SHA-256 `e6ea65304f51e16ee336a27783d185b09cdfff7117b4abe8ed8afabe2cb03b1f`.

## Production ownership boundary

QueueRexx owns the distributed infrastructure plane. Before an FD fleet job is started, QueueRexx must already provide:

- one authoritative JobNodeAllocator v0.6 lineage;
- the qualified `job.node.allocator.network/0.1` service/client route;
- durable Job-to-Node request replay state;
- Queue Fabric `queue.transport/2` inter-machine connectivity;
- authorised client/reply bindings;
- the Migratable Job remote-start route for the chosen destination.

FD consumes those services. FD must not bootstrap a second allocator, construct Queue Fabric topology, open service ports, guess localhost authority, synthesize a placement, or fall back to a direct payload start.

## Hard rules

1. Never launch `tools/run_fd_worker.rex` manually for a fresh job.
2. Never type or synthesize a placement ID / ownership epoch.
3. If the network allocator or remote-start service is unavailable, **NO START**.
4. The exact Job-to-Node lease must pass authoritative CHECK immediately before standard START.
5. `REMOTE_START_PENDING` / `START_PENDING_PLACEMENT_HELD` means execution is uncertain and the placement remains held. Do not allocate another owner or release automatically.
6. HANDOFF/RECOVER retain their normal migration authority paths.
7. Existing dev2 campaign state is provenance only; do not adopt it into a fresh dev8 run.

## Workload preparation on C/D/H/I

Create a fresh workspace, preserve the exact source SHA-256, and make the scientific launch spec with:

```bash
ROOT="$HOME/fd_night_migratable_dev8/tp0000X"
STATE="$ROOT/state"
OUT="$ROOT/evidence/tp0000X"
SPEC="$ROOT/launch.tsv"
mkdir -p "$STATE" "$(dirname "$OUT")"

export FD_SOURCE_PATH="$SOURCE"
export FD_SOURCE_EVIDENCE_REF="sha256:$(sha256sum "$SOURCE" | awk '{print $1}')"
export FD_OUTPUT_PREFIX="$OUT"
export FD_STATE_DIR="$STATE"
export FD_ANALYSIS_WALL_START='2023-10-10T00:00:00'
export FD_ANALYSIS_WALL_END='2023-10-10T05:00:00'
export FD_PROFILE='FD_NIGHT_F11'

rexx tools/make_fd_window_launch_spec.rex "$SPEC"
```

The normal fleet START is then performed through the QueueRexx-provided remote managed-placement path. `tools/allocate_fd_managed.rex` and `tools/start_fd_managed.rex` remain useful local/reference qualification surfaces, but are not instructions to construct independent authority on every worker.

A successful run must ultimately show the standard contracts:

```text
placement_api=migratable.job.placement/1
start_contract=migratable.job.start/1
migratable_job_version=0.2.5
migration_api=migratable.job/0.2
```

For a remote NEW start, the transport protocol is `migratable.job.remote-start/1`; destination lease verification is still authoritative Job-to-Node CHECK, not Queue delivery.

## TP00002 exclusion

TP00002 only:

```text
wall exclusion: 2023-10-10 03:12:00 <= t < 03:28:00
media interval: 00:10:05.000 <= t < 00:26:05.000
reason: USER_DECLARED_SCENE_OCCLUSION
```

TP00000, TP00001 and TP00003 have no such exclusion. Legacy ed209e/TP00009 remains outside this campaign restart.


## Required POSIX source guard

Add the POSIX package `src` and `src/providers` directories to `REXX_PATH`, and its host-built `native` directory to `LD_LIBRARY_PATH`. `tools/run_fd_worker.rex` requires `PosixGap.cls` and creates a coherent source-stability guard automatically. Production launch must not bypass this tool. The source guard is local execution evidence; cross-node resume continues to require the unchanged strong `source_evidence_ref`.
