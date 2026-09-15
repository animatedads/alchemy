# Deployment — FD Door Micro Motion v0.2-dev5

Runtime baseline: ooRexx 5.3.0 r13196; stock `csvStream.cls`; Foreign Runtime v0.22.6 with the host-local FFmpeg ABI 61/59 bridge runtime; Migratable Job v0.2.4 (`migratable.job/0.2`, `migratable.job.start/1`, `migratable.job.placement/1`); Job-to-Node v0.6; Crypto v0.8.3; Runtime Reference v0.4.

## Hard rules

1. Never launch `tools/run_fd_worker.rex` for a fresh job.
2. Never type a placement ID or ownership epoch into a NEW launch spec.
3. Never use the retired dev4 FD-specific authority receipt for NEW.
4. `PLAN` is advisory. `ALLOCATE` is the Job-to-Node ownership transition. `CHECK` verifies the exact native lease. `START` is allowed only after that verification.
5. If START fails or is ambiguous, placement remains held. Do not release it until runtime absence is independently proven.
6. Keep one canonical Job-to-Node durable journal for this campaign authority lineage. Worker nodes receive a byte-identical snapshot only for lease verification/START; they do not allocate from their copy.

## 1. Execution node: create the launch spec and measured probe

Set the normal job identity, exact source hash and wall-clock window. The launch-spec creator deliberately rejects `FD_SOURCE_PLACEMENT_ID`, `FD_SOURCE_OWNERSHIP_EPOCH` and `FD_SOURCE_AUTHORITY_REF`.

Measure the host rather than guessing:

```bash
export FD_AUTH_ARCHITECTURE="$(uname -m | tr '[:lower:]' '[:upper:]')"
export FD_AUTH_CPU_UNITS="$(getconf _NPROCESSORS_ONLN)"
export FD_AUTH_MEMORY_MIB="$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
export FD_AUTH_FREE_MEMORY_MIB="$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)"
export FD_AUTH_DISK_MIB="$(df -Pm -- "$FD_SOURCE_PATH" | awk 'NR==2 {print $2}')"
export FD_AUTH_FREE_DISK_MIB="$(df -Pm -- "$FD_SOURCE_PATH" | awk 'NR==2 {print $4}')"
export FD_AUTH_AVAILABLE_CPU_UNITS="$FD_AUTH_CPU_UNITS"
export FD_AUTH_OBSERVED_EPOCH_MS="$(date +%s%3N)"
export FD_AUTH_LEASE_MS=604800000

rexx tools/make_fd_window_launch_spec.rex "$SPEC"
rexx tools/make_fd_job_to_node_probe.rex "$PROBE"
```

The source evidence reference must be `sha256:<exact readable MP4 hash>`.

## 2. Authority node: PLAN -> ALLOCATE -> CHECK

Copy `SPEC.tsv` and `PROBE.tsv` unchanged to the authority node. Use one canonical durable journal for all four jobs and one placement-audit file per job (or one append-only audit if desired):

```bash
rexx tools/allocate_fd_managed.rex \
  "$SPEC" "$PROBE" "$AUTHROOT/placements.journal" "$AUDIT"
```

Success prints:

```text
FD_MANAGED_PLAN_OK ...
FD_MANAGED_ALLOCATE_OK placement_api=migratable.job.placement/1 ...
placement_id=<allocator value>
ownership_epoch=<allocator value>
```

The allocator, not FD and not the operator, creates those values. A retry of the same still-current placement returns `PLACED_REPLAY` and does not create a second ownership epoch.

## 3. Worker node: verify the exact durable lease and START

Copy the canonical journal snapshot and placement audit back to the assigned execution node **without editing either file**. Do not allocate from the worker copy.

Run:

```bash
rexx tools/start_fd_managed.rex \
  "$SPEC" "$PROBE" "$JOURNAL_SNAPSHOT" "$AUDIT"

rexx tools/check_fd_migratable_start.rex \
  "$SPEC" "$PROBE" "$JOURNAL_SNAPSHOT"
```

Success requires `FD_MIGRATABLE_CHECK_OK` and shows:

- `migratable_job_version=0.2.4`
- `placement_api=migratable.job.placement/1`
- `placement_receipt_api=migratable.job.placement.receipt/1`
- `start_contract=migratable.job.start/1`
- the exact Job-to-Node node/placement/ownership epoch from the journal.

Run `start_fd_managed.rex` a second time with the same `start_id`; it must replay the start receipt and must not launch a second worker.

## 4. Explicit release

Release is an authority-node operation after runtime absence/completion has been established independently:

```bash
export FD_RELEASE_CONFIRMED_NO_RUNTIME=YES
rexx tools/release_fd_managed.rex \
  "$SPEC" "$PROBE" "$AUTHROOT/placements.journal" "$AUDIT"
```

Without that explicit confirmation the tool refuses release.

## TP00002 exclusion

TP00002 only:

```text
wall exclusion: 2023-10-10 03:12:00 <= t < 03:28:00
media interval: 00:10:05.000 <= t < 00:26:05.000
reason: USER_DECLARED_SCENE_OCCLUSION
```

TP00000, TP00001 and TP00003 have no such exclusion. Existing dev2 output/state remains provenance only. Legacy ed209e/TP00009 remains untouched.
