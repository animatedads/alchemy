# Architecture Intentions ↔ ConnectSelector v0.1-dev1

**Observed and tested source:** Library `oorexx_connect_selector_v0.1-dev1.zip` (`oorexx.connect_selector/0.1`). This is the available API, not an invented prospective contract. Selection evidence is a read-only observation about **registered adapters**, not proof of deployed reachability, TLS, durability, security policy, actual queue storage, or authenticated broker access.

## Division of authority

- **Architecture Intention:** business request; distinct per-edge `REQUEST_REPLY`, `COMMAND`, `EVENT`, `STREAM` pattern; explicit scope and security ground rules; desired guarantee; locality; unresolved questions.
- **ConnectSelector:** `ConnectIntent(operation,mode,requirement,preferred,destination,options)`; `select()` and `explain()`; no automatic fallback after unsuccessful dispatch; registered adapter capability, not topology resolution.
- **Socket Provider/XTP:** physical network/carrier and native RexxOS MU/MI semantics; independently qualified.
- **SSC/Deployment:** immutable semantic dependency and target installation/load/activation authority. Planner output remains non-executable.

The optional `ArchitectureConnectSelectorAdapter` depends on `ConnectSelector.cls`, injected by the caller from an **explicit version-qualified source root**, and calls `selector~explain(intent)` only. It maps:

| Architecture binding | Preferred selector provider | Supported semantic modes in dev1 |
|---|---|---|
| `direct_call` | `DIRECT` | `REQUEST`, `NOTIFY` (same process) |
| `json_rpc` | `RPC` | `REQUEST`, `NOTIFY` (JSON-RPC 2.0; notifications unconfirmed) |
| `queue_fabric` | `QUEUE` | `ENQUEUE` (durability only when permanent queue + durable store present) |
| `jms` | **none** | `ConnectJmsBridge` boundary uses Queue Fabric on one side, JMS broker on the other |

A `REQUEST_REPLY` link bound to QUEUE is an explicit `ARCH_CONNECT_SEMANTIC_MISMATCH`. A streamed operation has no dev1 selector operation; do not map it to `NOTIFY`. Direct invocation cannot cross process boundaries even if hosts are adjacent. A `JMS` bridge must declare direction `JMS_TO_QUEUE` or `QUEUE_TO_JMS`, source and target, and collect evidence for broker, ack policy, transactions, ordering, deduplication, redelivery, dead letter and crash/recovery semantics. Source acknowledgement is NOT atomic with the destination commit. Do not claim exactly-once delivery.

## Example API

```rexx
::requires 'ArchitecturePlanner.cls'
::requires 'ArchitectureConnectSelectorAdapter.cls'

planner = .ArchitecturePlanner~new(catalog)
project = planner~project('example','Example')
project~connectSelectorAdapter = .ArchitectureConnectSelectorAdapter~new(actualSelector)
project~links~link('look','ui','catalog','core','REQUEST_REPLY','architect','Get a result')
project~links~bind('look','direct_call','Same-process design','architect')
project~links~placement('look','SAME_PROCESS','architect','layout://v1')
project~links~serviceIntent('look','cat.lookup','REQUEST','IMMEDIATE','','architect','Need value')
plan = planner~plan(project)  -- no service is executed
```

`connectSelectorReviews` exposes per-edge eligibility (`ELIGIBLE_REGISTERED` or a failure/status), retaining the requested operation, mode and guarantee. `interconnectAlternatives` projects independent policy permission/exclusion per candidate, with governing-rule attribution. **Permission is not capability**, and adapter registration is not deployment qualification. Policy violations stay blocking even when ConnectSelector supports a route.

A planner without a connected selector instance returns an unanswered `link_*_selector` question for a configured native route; it never invents a successful provider. The `build-request` includes only chosen `connect_selector` and selected runtime/bridge dependencies; XML/JSON/web middleware does not become compulsory just because the planner runs.

## Remaining work

Prove deployment-specific `ConnectCallAdapter`/`ConnectQueueAdapter` registration with real Queue manager and JSON-RPC Fabric; qualify TLS/authentication, queue permanence and persistent store in the target; verify actual JMS port client/session and broker ack transaction behaviour, crash/replay, DLQ and backout under failure, rather than treating mock tests as live evidence. Add SSC and Deployment dependency locks before turning any architecture request into an executable build.

## ConnectSelector dev2 policy qualification (dev7)

ConnectSelector dev2 requires explicit `ConnectRoutePolicy` allow grants scoped to operation, mode, provider and destination. A denied or unbound destination is not eligible, even with a registered adapter; the read-only `explain()` probe is used and nothing executes. This is a stronger rule than the historical dev1 compatibility test. The planner must show both candidate feasibility and applicable architectural ground rules, never treating either alone as production authorization.
