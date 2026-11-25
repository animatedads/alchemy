# rexxos_arbitrator v0.1-dev3

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Written by: Claude (Opus 5.5).

## What it is

A machine does not run provisioning scripts. It holds **demands**. Its
**MachineArbitrator**, the one authority over that machine's resources, turns the
demands and the machine's state into a **ProvisionPlan**: the ordered steps that
reach the target state. The **ClusterArbitrator** does cross-arbitration across
MUs. Each MU's own arbitrator plans its part; the cluster orders the parts and
adds the routing.

The **PlanRunner** carries a machine plan out through an effector, journalled, so
that a pulled plug loses nothing.

Nothing here touches a real machine, route or DNS record. Machine state is
supplied by hand, and the effector is simulated.

## New in dev3

### Recovery is pre-approved

Tom Dyer approved this rule on 25 November 2026 ("continue"):

- The disappearance of a node is just that: something the cluster grid deals
  with.
- **Recovery steps run without waiting**, and are logged with their cause and
  reported afterwards. The recovery steps are:
  - `FENCE_ROLE`;
  - `ROUTE_SERVICE`, moving a role's or a dead MU's service route;
  - `ACTIVATE_TASK` and `START_TASK` of what existed before the node went.
- **A recovery step may only restore what existed.** A plan that would add
  capacity or change exposure drops back to NEEDS TOM'S DIRECT APPROVAL, and
  says why. Adding swap, adding a cache, swapping out other work and
  repointing DNS all do that.
- **Everything else still needs Tom's direct yes**: provisioning, moving a
  healthy service, DNS, firewalls, keys, reboots.
- This rule covers the arbitrator's own plans. It changes nothing about orders
  sent to Codex or anyone else.

How it is built:
- `ProvisionPlan` has a `purpose` (`PROVISION` or `RECOVERY`),
  `approvalClass` (`RECOVERY` or `TOM`) and `recoveryProblem`.
- `muDown` makes a `RECOVERY` plan, and now also restores the services that
  lived on the dead MU. It tries the same site first, then the service's home
  zone, then anywhere. Placement is restore-only: no swap, no new cache, and
  no other task swapped out.
- A `TEMPORARY` service starts afresh and the loss is stated. A `CHECKPOINT`
  service loses the work since its last checkpoint, and that is stated too.
- **A DNS-edge service's recovery needs approval**, because repointing DNS
  changes public exposure. **Behind XTP gateways it needs none.**

### A plan survives a pulled plug (src/PlanRunner.cls)

Tom Dyer, 2026-11-25: the lab manager pulled the breaker 45 minutes before the
deadline. If you hadn't saved your work and planned your recovery, it was on
you.

**The journal.** `PlanRunner~run(plan, id, now)` records:
1. the whole plan;
2. then, for each step:
   1. `BEGIN`;
   2. the effector performs the step;
   3. the ledger is updated, and a new numbered snapshot is written saying
      which step it is applied through;
   4. `DONE`;
3. `END`.

**Resuming.** `PlanRunner~resume(now)`, run by a fresh arbitrator after the
plug is pulled, does the following:
1. loads the newest complete snapshot;
2. finds the step that was begun but not finished;
3. asks the effector whether that step's effect is present;
4. performs it again only if it didn't happen, and applies it to the ledger
   only if the ledger lacks it;
5. carries on with the remaining steps.

**Damage from the power cut:**
- A journal line torn by the power cut lacks its `|END` and is ignored. The
  next record starts on a line of its own; without that, the torn line would
  join the next record and fake a step.
- Snapshots are new files, never overwritten in place. A torn one, without its
  final `END`, is ignored.

**Logging.** Progress goes through oorexx_logging v0.7 (`LogService`,
`LogRule`, `loggerFor`). `LogLineTarget` prints each event as one line, so the
run is never a black box.

**Text forms.** `Demand`, `ProvisionStep` and `MachineState` have text forms
(`toText`/`fromText`, `toLines`/`fromLines`). `|` and `%` are escaped.

## Tom Dyer's direction (25 November 2026)

- **A machine is a set of event triggers**, not a set of scripts. Nobody decides
  swap at provisioning: a demand that needs it gets it in the plan.
- **The machine arbitrator asks the cluster** for cross-arbitration. It never
  moves a task itself.
- **Write-back or write-through is decided case by case**, from the request.
- **An MU is a processing unit that hosts MIs, and is disposable**, like an MI.
  So an MU holds nothing that can't be rebuilt or moved.
- **Tasks run on a cluster the way IBM Tokyo's Aglets did.** They are created,
  dispatched, retracted, deactivated (swapped out whole) and activated.
- **"A lot of access from the USA today"** is answered by moving the website's MI
  wholesale. If the Rasen Falcon site is accessed from Australia between 22:00
  and 08:00 GMT, it is served from that zone. From 08:00 GMT it runs on UK tin.
- **XTP addresses services, not equipment.** LDAP.main and LDAP.spare are
  whatever answers those roles this minute, kept on separate sites. When
  LDAP.main goes down, LDAP.spare becomes LDAP.main.

## The machine arbitrator (src/Arbitrator.cls)

- **Where state lives.** A demand's `stateWhere` is `FABRIC`, `CHECKPOINT` or
  `TEMPORARY`. `LOCAL` is refused. `DURABLE` and `READONLY` data default to
  `FABRIC`; `TEMPORARY` data defaults to `TEMPORARY`.
- **Swapping out whole.** A task whose state survives (`FABRIC` or `CHECKPOINT`)
  can be deactivated. The steps are:
  1. its hook runs;
  2. its state is written and verified against a digest;
  3. its RAM is released.

  It is activated again here or anywhere. The arbitrator prefers this to adding
  swap, and to making a more important demand wait. Each deactivation asks the
  cluster where the task resumes. A task with `TEMPORARY` state is never
  swapped out: dev1's behaviour (swap, or ask the cluster to move it and wait)
  still applies to it.
- **Importance.** `importance` is the priority, named as in WLM.
- **Everything else is unchanged from dev1:**
  - caches by request;
  - read-only RAM stores, verified before the root switch;
  - hysteresis;
  - simulation of every intermediate state;
  - NEEDS TOM'S DIRECT APPROVAL on every step that changes a machine.

## The cluster arbitrator (src/ClusterArbitrator.cls)

### ServicePlacement

Each service has:
- a demand;
- an XTP service address;
- a public edge (`GATEWAY`, `DNS` or `NONE`) and a public name;
- a home zone and a minimum residence;
- rules. Each rule names a zone, an optional GMT window and a minimum share of
  the access. The first rule that matches wins; otherwise the service runs in
  its home zone.

A move is a **route change on the service address**: clients keep the same
address. How the move runs depends on where the service's state is:

| State | Order | Outage |
|---|---|---|
| `FABRIC` | activate on the target, check it, move the route, (edge DNS: repoint, wait the TTL), then release the old copy | none: both serve during the overlap |
| `CHECKPOINT` | deactivate the old copy, activate on the target, check it, move the route | the activation time (plus the TTL with edge DNS) |
| `TEMPORARY` | does not move | — |

With edge `GATEWAY`, the public name points at XTP gateways and never changes.
With edge `DNS`, the public name names equipment, so it is repointed.

A target must take the service without asking anything of the cluster.
Otherwise the service stays where it is, and the cluster says why.

### RolePair (LDAP.main, LDAP.spare)

- Main and spare must be on separate sites. The spare's state must be on a
  fabric.
- `muDown(mu)` (quorum has decided) does the following:
  1. **Fences the old main.** The role's epoch is raised, so an answer from the
     old main is refused if it comes back.
  2. **Moves the `.main` route to the spare.**
  3. **Makes a new spare** on a site other than the new main's. It must catch up
     (replica generation) before `.spare` is routed to it.
- If no other site can take a spare, the plan says so. Running without a spare
  is reported, never hidden.

## Plans as printed

The Rasen Falcon site at 23:00 GMT, with 70% of its access from Australia
(edge DNS):

```
 1. [au1] ACTIVATE_TASK rasen-site            NEEDS TOM'S DIRECT APPROVAL
 2. [au1] ADD_CACHE rasen-site 300MiB READONLY NEEDS TOM'S DIRECT APPROVAL
 3. [au1] CHECK_SERVING rasen-site
 4. [au1] ROUTE_SERVICE rasen-site            NEEDS TOM'S DIRECT APPROVAL
    - register rasen.site with au1's XTP daemon
    - publish the route (LDAP) and withdraw uk1's
    - clients keep the same service address
 5. [au1] REPOINT_DNS rasen-site              NEEDS TOM'S DIRECT APPROVAL
 6. [uk1] WAIT_DNS rasen-site                 (300 s, the record's TTL)
 7. [uk1] DROP_CACHE rasen-site 300MiB READONLY NEEDS TOM'S DIRECT APPROVAL
 8. [uk1] DEACTIVATE_TASK rasen-site          NEEDS TOM'S DIRECT APPROVAL
```

uk1 is pulled:

```
 1. [au1] FENCE_ROLE LDAP-2       raise LDAP.main's epoch to 2
 2. [au1] ROUTE_SERVICE LDAP-2    register LDAP.main with au1's XTP daemon
 3. [uk2] ACTIVATE_TASK LDAP-3
 4. [uk2] CHECK_SERVING LDAP-3    compare its replica generation with LDAP.main's
 5. [uk2] ROUTE_SERVICE LDAP-3    register LDAP.spare with uk2's XTP daemon
```

## Still for Tom to decide

1. **LDAP carries the routes, including LDAP.main's own.** Publishing the new
   LDAP.main route must not depend on the LDAP.main that just died. The XTP
   daemons need the fallback the design already names: manual override files,
   or a direct daemon announcement.

## Tests

```
PACKAGES=/path/to/packages bash tests/run_tests.sh
```

130 checks: dev1's 48, dev2's 56 and dev3's 26. dev3's checks cover:
- the recovery class: the LDAP failover and the dead MU's services are
  pre-approved; a DNS edge needs approval; an ordinary plan, and a "recovery"
  plan that adds swap, are not pre-approved;
- the text forms;
- the plug pulled at step 2 before the step, after it, and after the snapshot,
  and once more with a torn journal line and a torn snapshot. In each case
  resume finishes, every step is done exactly once, and the ledger matches
  the machine;
- that the torn-journal check fails without the torn-line repair (checked by
  hand as a control).

dev2's checks cover:
- swapping out instead of waiting and instead of adding swap;
- activating again;
- `TEMPORARY` state not swapped out;
- a write-back cache flushed before a swap-out;
- the state rule;
- the site following the sun: stays at midday, moves to AU at 23:00, is held
  by its residence at 23:30, goes home at 08:30, moves to the US on US traffic;
- the gateway edge, with no DNS steps;
- no room in a zone;
- a checkpoint handover;
- a `TEMPORARY` service not moving;
- LDAP.main/spare failover, a lost spare, and no site left.

Passes on ooRexx 5.2.0 and 5.3.0.

## Not done

- **Cluster plans are not journalled yet.** The PlanRunner carries out machine
  plans; cluster and recovery plans still need a durable runner of their own.
- **Inputs from the pump.** Access by zone, RAM and PSI pressure should arrive
  as LogEvents (oorexx_logging v0.8, REQ-00005849). The quorum decision that
  an MU is dead should arrive as an event.
- **Goals.** The arbitrator has importance but not response-time goals; goals need the
  pressure input to mean anything.
- **The real steps.** The XTP daemon registration, the LDAP route publication,
  the epoch fence, DNS, the checkpoint write, and rehearsal on the Virtual PC.
- **Two replicas of every state-freezable job**, as the XTP design asks; only
  role pairs are modelled.
- **Failure domains below the site.** The provider and the power feed are not
  modelled.
- **Shrinking a cache.**
- **A real effector.** It would check a step's effect on the machine itself.
  The simulated one remembers what it did.
