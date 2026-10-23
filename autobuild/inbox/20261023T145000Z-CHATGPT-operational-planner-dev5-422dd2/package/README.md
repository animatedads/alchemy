# ooRexx Operational Degradation Planner v0.1-dev5

Transport-neutral registered operational classes plus explicit capacity domains.

A class still answers **what survives** in NORMAL / DEGRADED / CONSTRAINED / EMERGENCY operation. dev5 adds the missing answer to **30% of what?**: a named capacity domain with a declared nominal and current byte rate.

Examples:

```text
normal.storage / NORMAL
  per_context_cap_percent = 30
  max_parallel_contexts   = 2
  aggregate_cap_percent   = 60

capacity domain
  mi1-mu2.ingress
  nominal = 100 MB/s
  current = 100 MB/s
```

Two admitted `normal.storage` contexts therefore reserve 30 MB/s each and consume 60% of that ingress domain. A third context is refused. If the current capacity estimate falls to 50 MB/s, the same class decision yields 15 MB/s per admitted context.

The domain is deliberately not an IP address, interface address, or XTP route. It identifies the shared resource against which policy percentages are accounted. A provider/fabric maps its own work to the appropriate domain.

## Control surfaces

Native:

```sh
opctl capacity set mi1-mu2.ingress 100000000 90000000
opctl capacity show mi1-mu2.ingress
opctl capacity list
```

ooRexx:

```rexx
cap=.OperationalCapacityRegistry~new('/path/to/opctl')
cap~set('mi1-mu2.ingress',100000000,90000000)

gov=.OperationalCapacityGovernor~new(cap,planner)
ticket=gov~acquire('normal.storage','normal','mi1-mu2.ingress')
```

A returned ticket contains `PERCENT` and `BYTES_PER_SEC`. The governor owns admission accounting only; an XTP/NORM/TCP/Storage enforcer still owns actual byte pacing or refusal. This keeps the policy useful outside XTP.

State policy syntax remains:

`disposition:rate:fallback:protected:per_context_cap:max_parallel_contexts:aggregate_cap`

## dev5 pressure hardening

Active capacity tickets are now live objects rather than admission-time snapshots. Capacity-domain changes can refresh the byte rate of existing contexts, and `reconcile()` reapplies a class policy to already-live contexts when the operating state changes. Excess contexts are suspended (ticket retained, admitted=false, zero rate) so an upper layer can preserve transfer identity/checkpoint state and restore the context later.

The native governor is mutex-protected and includes a concurrent pressure regression. The ooRexx governor exposes `refreshDomain`, `reconcile`, `ticket`, `activeContexts` and `activePercent` for Storage Fabric and other service owners.
