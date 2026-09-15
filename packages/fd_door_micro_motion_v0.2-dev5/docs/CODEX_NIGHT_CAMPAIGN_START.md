# Codex runbook — FD 00:00–05:00 night campaign, dev5

Do not improvise. This runbook uses FD Door Micro Motion v0.2-dev5 plus Migratable Job v0.2.4 managed initial placement.

## Immutable assignment

- ed209c / TP00003 / `20231010_033544_tp00003.mp4` / SHA-256 `158321e60849bdd1692bf5d2de595538e998845c1d959150dd99097296c84235` / wall origin `2023-10-10T03:35:44`
- ed209d / TP00000 / `20231009_222005_tp00000.mp4` / SHA-256 `b1f9332583f6ceb20424dbc564687688718c48207ca474004c386ac40fddc17` / wall origin `2023-10-09T22:20:05`
- ed209h / TP00001 / `20231010_002359_tp00001.mp4` / SHA-256 `0ea25da2dd4c2cf9d96ed04c1392d332d8335694db0fcc2af399ed6eeaa05cc3` / wall origin `2023-10-10T00:23:59`
- ed209i / TP00002 / `20231010_030155_tp00002.mp4` / SHA-256 `301b519e9894758cb9086b68d0b0691328d172977fd9a95f773eb3ea3ad8ad61` / wall origin `2023-10-10T03:01:55`

ed209e / TP00009 is legacy. Do not touch it.

Use Migratable Job v0.2.4 SHA-256 `c6cfadcd64ad9f803eea14e37854021ef7eae2015a1c54dcc3c799c04f1517df`.

## A. C/D/H/I — prepare, but do not start

Verify no direct FD worker exists and source hash is exact. Keep old dev2 trees untouched. Use fresh roots:

```text
~/fd_night_migratable_dev5/tp00000
~/fd_night_migratable_dev5/tp00001
~/fd_night_migratable_dev5/tp00002
~/fd_night_migratable_dev5/tp00003
```

Identity:

```text
C: FD_JOB_ID=FDN-TP00003  FD_PARTITION_ID=tp00003  FD_START_ID=FDNEW-FDN-TP00003-1  FD_SOURCE_NODE_ID=ed209c
D: FD_JOB_ID=FDN-TP00000  FD_PARTITION_ID=tp00000  FD_START_ID=FDNEW-FDN-TP00000-1  FD_SOURCE_NODE_ID=ed209d
H: FD_JOB_ID=FDN-TP00001  FD_PARTITION_ID=tp00001  FD_START_ID=FDNEW-FDN-TP00001-1  FD_SOURCE_NODE_ID=ed209h
I: FD_JOB_ID=FDN-TP00002  FD_PARTITION_ID=tp00002  FD_START_ID=FDNEW-FDN-TP00002-1  FD_SOURCE_NODE_ID=ed209i
```

Common environment:

```bash
ROOT="$HOME/fd_night_migratable_dev5/tp0000X"
STATE="$ROOT/state"
OUT="$ROOT/evidence/tp0000X"
SPEC="$ROOT/launch.tsv"
PROBE="$ROOT/job-node.probe.tsv"
mkdir -p "$STATE" "$(dirname "$OUT")"

export FD_SOURCE_PATH="$SOURCE"
export FD_SOURCE_EVIDENCE_REF="sha256:$(sha256sum "$SOURCE" | awk '{print $1}')"
export FD_OWNER_NODE_ID="$FD_SOURCE_NODE_ID"
export FD_OUTPUT_PREFIX="$OUT"
export FD_STATE_DIR="$STATE"
export FD_ANALYSIS_WALL_START='2023-10-10T00:00:00'
export FD_ANALYSIS_WALL_END='2023-10-10T05:00:00'
export FD_PROFILE='FD_NIGHT_F11'
export FD_ALLOWED_DESTINATION_NODES='ed209a,ed209b,ed209c,ed209d,ed209e,ed209h,ed209i'
unset FD_SOURCE_PLACEMENT_ID FD_SOURCE_OWNERSHIP_EPOCH FD_SOURCE_AUTHORITY_REF
```

Set the assigned wall origin. TP00000/1/3 use `FD_EXCLUSION_COUNT=0`. TP00002 only:

```bash
export FD_EXCLUSION_COUNT=1
export FD_EXCLUSION_1_ID='FDX-POLICE-F11'
export FD_EXCLUSION_1_WALL_START='2023-10-10T03:12:00'
export FD_EXCLUSION_1_WALL_END='2023-10-10T03:28:00'
export FD_EXCLUSION_1_REASON='USER_DECLARED_SCENE_OCCLUSION'
```

Measure the node:

```bash
export FD_AUTH_ARCHITECTURE="$(uname -m | tr '[:lower:]' '[:upper:]')"
export FD_AUTH_CPU_UNITS="$(getconf _NPROCESSORS_ONLN)"
export FD_AUTH_MEMORY_MIB="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
export FD_AUTH_FREE_MEMORY_MIB="$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)"
export FD_AUTH_DISK_MIB="$(df -Pm -- "$SOURCE" | awk 'NR==2 {print $2}')"
export FD_AUTH_FREE_DISK_MIB="$(df -Pm -- "$SOURCE" | awk 'NR==2 {print $4}')"
export FD_AUTH_AVAILABLE_CPU_UNITS="$FD_AUTH_CPU_UNITS"
export FD_AUTH_OBSERVED_EPOCH_MS="$(date +%s%3N)"
export FD_AUTH_LEASE_MS=604800000

rexx tools/make_fd_window_launch_spec.rex "$SPEC"
rexx tools/make_fd_job_to_node_probe.rex "$PROBE"
```

Require `FD_LAUNCH_SPEC_OK` and `FD_MANAGED_PROBE_OK`. Copy SPEC and PROBE to ed209a. Do not start yet.

## B. ed209a — one canonical Job-to-Node journal, standard managed placement

```bash
AUTHROOT="$HOME/fd_job_to_node_managed_20231010"
mkdir -p "$AUTHROOT"
JOURNAL="$AUTHROOT/placements.journal"
```

For each job run:

```bash
AUDIT="$AUTHROOT/<job>.placement.audit"
rexx tools/allocate_fd_managed.rex "$SPEC" "$PROBE" "$JOURNAL" "$AUDIT"
```

Require `FD_MANAGED_PLAN_OK` then `FD_MANAGED_ALLOCATE_OK`. Do not invent or edit the emitted placement/epoch. Retry is allowed only if it returns the same current placement (`PLACED_REPLAY`).

After all four allocations, copy the **same canonical journal snapshot** to each assigned worker along with that job's SPEC, PROBE and AUDIT. Verify SHA-256 of the journal snapshot before/after transfer. Workers must not allocate from their copy.

## C. C/D/H/I — CHECK -> START through managed API

```bash
rexx tools/start_fd_managed.rex \
  "$SPEC" "$PROBE" "$ROOT/placements.journal" "$ROOT/placement.audit"

rexx tools/check_fd_migratable_start.rex \
  "$SPEC" "$PROBE" "$ROOT/placements.journal"
```

Success requires:

```text
FD_MANAGED_START_OK
placement_api=migratable.job.placement/1
placement_receipt_api=migratable.job.placement.receipt/1
start_contract=migratable.job.start/1
migratable_job_version=0.2.4
FD_MIGRATABLE_CHECK_OK
```

Run `start_fd_managed.rex` once again with the same files. It must report replay and must not create a second payload PID.

`run_fd_worker.rex` is never launched manually. `start_fd_migratable.rex` is retired and exits 66.

## D. Failure rule

If `start_fd_managed.rex` returns `START_FAILED_PLACEMENT_HELD`, STOP. Do not allocate a replacement and do not release automatically. Determine whether a worker side effect exists. Only after proving there is no execution may ed209a run:

```bash
export FD_RELEASE_CONFIRMED_NO_RUNTIME=YES
rexx tools/release_fd_managed.rex "$SPEC" "$PROBE" "$JOURNAL" "$AUDIT"
```

That is the only safe cleanup path.
