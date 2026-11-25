# rexxos_arbitrator v0.1-dev1

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Written by: Claude (Opus 5.5).

## What it is

A machine does not run provisioning scripts. It holds **demands**. Its
**MachineArbitrator**, the one authority over that machine's resources, turns the
demands and the machine's state into a **ProvisionPlan**: the ordered steps that
reach the target state.

Swap is the example (Tom Dyer, 2026-11-25). Nobody decides swap at install time.
An MI with a service has a memory requirement. If it can start without swap, it
starts. If it cannot, the plan provisions swap first. When that demand ends or
moves, the plan removes the swap, and spare RAM becomes fast storage for the
demands that want it.

dev1 is the planner only. Nothing here touches a real machine.

## Rules

- **The arbitrator never moves a task.** It asks the cluster for
  cross-arbitration (`ASK_CLUSTER`). The answer arrives as an event, and the
  arbitrator re-plans (Tom Dyer, 2026-11-25).
- **The cache mode is decided per request** (Tom Dyer, 2026-11-25). By default,
  the request's durability decides:

  | Durability | Cache mode |
  |---|---|
  | `READONLY` | `READONLY` |
  | `TEMPORARY` | `WRITEBACK` |
  | `DURABLE` | `WRITETHROUGH` |

  A request may name its own mode. `DURABLE` data may not use `WRITEBACK`.
- **A plan is data.** Each step names the demand it serves, why, what it does
  (`actions`), and its inverse.
- **Every step that changes the machine is marked** "NEEDS TOM'S DIRECT
  APPROVAL". Only `ASK_CLUSTER` is not.
- **The plan is simulated step by step** on a copy of the state. It is refused
  (`ok` is false, `REFUSED:` lines) if any intermediate state breaks a rule:
  - resident RAM within the budget;
  - RAM plus pageable within RAM plus swap;
  - disk and fabric not overcommitted;
  - no dirty write-back cache dropped.
- **Steps free before they take:**
  1. stop withdrawn tasks;
  2. flush and drop caches;
  3. add swap;
  4. start tasks;
  5. remove swap;
  6. add caches.
- **A running task keeps its place until the cluster moves it.** A new
  higher-priority demand that does not fit asks the cluster to move the
  lowest-priority running task. Its own start is `WAITING`.
- **Hysteresis.** A new cache needs headroom (15% of RAM by default). An
  existing one only has to fit. Swap has a minimum lifetime (600 s by default);
  removing it earlier is `DEFERRED`.
- **A read-only store holds the whole data and replaces the root.** It is
  verified against a digest before the switch. Giving it back needs no flush.
- **A cache in front of a drive may hold part of the data** (at least 256 MiB).

## Classes (src/Arbitrator.cls)

| Class | Holds |
|---|---|
| `Demand` | id, priority, ramMiB, pageableMiB, storageMiB, storageWhere (NONE LOCAL FABRIC), wantsRamSpeed, durability, cacheMode |
| `MachineState` | RAM, base use, free disk and fabric, swap, running tasks, caches; `violations`, `apply` |
| `ProvisionStep` | kind, demand, sizeMiB, mode, cause, status (PLANNED DEFERRED WAITING), note; `actions`, `inverse`, `changesMachine` |
| `ProvisionPlan` | steps, violations; `planned`, `kinds`, `ok`, `needsApproval`, `describe` |
| `MachineArbitrator` | `plan(demands, now)`, `completed(step, now)` |

Step kinds: `STOP_TASK FLUSH_CACHE DROP_CACHE ADD_SWAP START_TASK REMOVE_SWAP ADD_CACHE ASK_CLUSTER`.

## Tom's T1/T2, as the arbitrator plans it

The machine has 8192 MiB of RAM, with 1024 MiB used by the base system.
- T1 needs 20000 MiB of fabric storage, would like RAM speed, and is `TEMPORARY`.
- T2 needs 9000 MiB of RAM, of which 4000 MiB may page.

```
 1. ADD_SWAP 2579MiB   NEEDS TOM'S DIRECT APPROVAL
    why: pageable RAM of placed tasks exceeds free RAM by 2579 MiB with margin
 2. START_TASK T2   NEEDS TOM'S DIRECT APPROVAL
 3. START_TASK T1   NEEDS TOM'S DIRECT APPROVAL
---- T2 moved away, 1000 s later
 1. STOP_TASK T2
 2. REMOVE_SWAP 2579MiB
    - bring swapped pages back into RAM
    - disable and delete the swap file
 3. ADD_CACHE T1 5427MiB WRITEBACK
    why: spare RAM above 1229 MiB headroom; demand T1 wants RAM speed
```

If a RAM demand arrives later, T1's cache is flushed, then dropped, then the new
task starts.

## Tests

```
bash tests/run_tests.sh
```

48 checks. They cover:
- the Rasen Falcon static site (RAM store on low load, given back to a RAM
  demand, comes back when that demand ends);
- hysteresis;
- T1/T2;
- write-back flush;
- write-through;
- a request that names its own cache mode;
- the cluster cases (an unpageable demand bigger than RAM, moving a
  lower-priority task, no disk for swap, no fabric space);
- the invariants;
- input validation.

Passes on ooRexx 5.2.0 and 5.3.0.

## Not done

- **Inputs from the pump.** RAM, swap, PSI pressure and disk should come from
  the LogEvents of the native providers (oorexx_logging v0.8, ordered as
  REQ-00005849). In dev1 they are supplied by hand.
- **Logging.** There is no oorexx_logging progress log yet, because nothing
  runs here.
- **The Virtual PC rehearsal and the real steps.** These cover `swapon`, the RAM
  store, the cache (for example dm-writecache) and the root switch.
- **The cluster arbitrator's side of ASK_CLUSTER.**
- **Shrinking a cache** (dev1 drops it), and checking that moving the blocking
  task is enough.
- **Durability of the arbitrator's own state** across restarts.
