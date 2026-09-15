# QueueBash capability preservation map

QueueRexx must preserve QueueBash's operational knowledge, not merely its state directories. The 0.18.144 `queue dev functions` inventory exposes mature families for platform detection, policy, sandbox/seccomp preparation, runner selection, systemd observation/control, process trees, health, sentinel/worker reconciliation, runtime capability monitoring, remote administration, cloud/service facts, and fleet daemon behaviour.

The object-oriented translation is **not** one provider per shell function. It groups the existing semantics behind stable capability contracts while leaving state authority in the QueueRexx compatibility kernel.

| QueueBash capability family | Representative 0.18.144 surfaces | QueueRexx owner | Provider direction |
|---|---|---|---|
| Platform capability discovery | `_queue_platform_detect_id`, `_queue_platform_*`, systemd user probe, runtime capability probes | provider registry + fact model | `PlatformFactProvider` |
| Job runner selection/start | `_queue_runner_for_job`, direct execution, systemd transient-unit helpers | kernel selector + provider | `RunnerProvider` (`direct`, `systemd`, later platform-specific runners) |
| Runner liveness/control | PID/PGID logic, systemd `ActiveState`/`SubState`/`MainPID`, unit tree kill | provider evidence; kernel decides transitions | runner `observe/terminate`, optionally `ProcessObservationProvider` |
| Process tree/metrics | child PID recursion, PID report, effective PID, systemd metrics | observation layer | `ProcessObservationProvider` |
| Sandbox and seccomp | `_queue_emit_sandbox_*`, `_queue_emit_seccomp_*`, policy requirement ranking | policy + preparation pipeline | `IsolationProvider` implementations for direct/systemd mechanisms |
| CPU/memory/resource controls | systemd quota normalization and runner-specific limits | preparation + observation | `ResourceControlProvider` |
| Runtime behavioural caps | `caps.d/runtime.sh`: no spawned shell, network tools/sockets, local-only sockets, allowed ports | recovery-safe monitor coordinator | `RuntimeGuardProvider` |
| Asset prerequisites | `assets.d/*` including VM/libvirt, Docker, Kubernetes, LXC, vSphere, Vagrant, cloud, DB, network, legal and integrity checks | preflight coordinator | `AssetProvider` family |
| VM/container prerequisites | `assets.d/vm.sh`, `docker.sh`, `k8s.sh`, `lxc.sh`, `vsphere.sh`, `vagrant.sh`, `VMCONTAINER` class | preflight assets, not generic PID logic | registered asset providers; runner provider only when QueueBash actually launches through that mechanism |
| Policy/authorization | submit/execution policy checks, class/security statements, signatures, authorisation, policy blocked state | policy coordinator + transition kernel | `PolicyProvider`; provider returns decision only |
| Health/stale detection | `_queue_health_*`, duplicate reconciliation | kernel scan/recovery | providers supply typed observations; `QueueRecoveryManager` owns repair |
| Sentinel/worker lifecycle | policy recheck, deadlines, waiting/pending movement, min workers, worker reconciliation | kernel orchestration | providers provide evidence/mechanism only |
| Service/remote facts | remote admin/dependency, service/resource provider families | capability/query layer | `ServiceFactProvider` and specialist providers |
| Node/fleet placement | remote/fleet choice and authority | placement authority before local runner choice | `PlacementProvider`, principally existing Job-to-Node Allocator |
| Events/triggers | QueueBash event records + future durable callbacks | event coordinator | existing Object Queue Fabric + Runtime Registry for durable trigger execution |

## Why VM/container checks are not automatically runners

QueueBash already distinguishes **a prerequisite about infrastructure** from **the mechanism that launches the job**. For example, `assets.d/vm.sh` checks libvirt domain state, disk format/age, network/pool state, snapshots and vCPU count; the `VMCONTAINER` class can declare Docker/Kubernetes/VM/LXC/vSphere/Vagrant assets. Those facts may gate a job while the payload itself is still started by `direct` or `systemd`.

QueueRexx preserves that distinction:

```text
JobRequirement
  -> PolicyProvider decisions
  -> AssetProvider prerequisites
  -> optional PlacementProvider lease/node
  -> PlatformFactProvider facts on selected node
  -> IsolationProvider + ResourceControlProvider plan
  -> RunnerProvider selection/launch
  -> ProcessObservationProvider + RuntimeGuardProvider monitoring
  -> QueueTransitionService completion/failure/recovery
```

This prevents a monolithic "Linux provider" from becoming a new version of the old `if/case` tree.

## Three-state/typed fact rule

Capability discovery and monitoring must preserve uncertainty. A missing tool, a known negative result, and an unqueryable result are different evidence. Providers therefore need explicit support/denial codes and future observations use typed states such as `LIVE`, `DEAD`, `UNKNOWN`, and `LAUNCH_PENDING` rather than booleans where uncertainty changes recovery behaviour.

## No provider owns state

No provider may directly move a `.job` file among `pending`, `running`, `failed`, `interrupted`, `pol_blocked`, or terminal directories. Providers return plans, observations, decisions and operation results. Only `QueueTransitionService` may commit a QueueBash-compatible state transition under the shared lock and recovery rules.
