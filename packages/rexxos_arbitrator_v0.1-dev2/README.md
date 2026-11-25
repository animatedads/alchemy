# rexxos_arbitrator v0.1-dev2

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Written by: Claude (Opus 5.5).

## What it is

A machine does not run provisioning scripts. It holds **demands**. Its
**MachineArbitrator**, the one authority over that machine's resources, turns the
demands and the machine's state into a **ProvisionPlan**: the ordered steps that
reach the target state. The **ClusterArbitrator** does cross-arbitration across
MUs. Each MU's own arbitrator plans its part; the cluster orders the parts and
adds the routing.

Nothing here touches a real machine, route or DNS record. Machine state is
supplied by hand.

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

## Two things for Tom to decide

1. **Failover cannot wait for approval.** Every step that changes a machine
   carries NEEDS TOM'S DIRECT APPROVAL, and a failover is a set of such steps.
   Automatic failover means an exception to that rule for named steps
   (`FENCE_ROLE`, and `ROUTE_SERVICE` for a role). Until you make it, these
   plans are proposals.
2. **LDAP carries the routes, including LDAP.main's own.** Publishing the new
   LDAP.main route must not depend on the LDAP.main that just died. The XTP
   daemons need the fallback the design already names: manual override files,
   or a direct daemon announcement.

## Tests

```
bash tests/run_tests.sh
```

104 checks: dev1's 48 machine checks (kept) and 56 new ones. The new ones cover:
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

- **Inputs from the pump.** Access by zone, RAM and PSI pressure should arrive
  as LogEvents (oorexx_logging v0.8, REQ-00005849). The quorum decision that
  an MU is dead should arrive as an event.
- **Goals.** dev2 has importance but not response-time goals; goals need the
  pressure input to mean anything.
- **The real steps.** The XTP daemon registration, the LDAP route publication,
  the epoch fence, DNS, the checkpoint write, and rehearsal on the Virtual PC.
- **Two replicas of every state-freezable job**, as the XTP design asks; only
  role pairs are modelled.
- **Failure domains below the site.** The provider and the power feed are not
  modelled.
- **Shrinking a cache**, and keeping the arbitrator's own state across
  restarts.
