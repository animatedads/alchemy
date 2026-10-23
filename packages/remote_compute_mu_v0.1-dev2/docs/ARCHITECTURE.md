# Remote Compute MU — control, execution, authority and recovery (v0.1-dev2)

## Placement in the RexxOS estate

```text
Jobs / Intention -> Generalized Compute Intentions -> Job-to-Node v0.6
                         |                  placement lease
                         + WLU Authority            |
                                                   v
                 mesh / Connect Selector -> Remote Compute MU
                                               |       |
                           Storage Fabric <----+       +---- status / reconcile
                                               |
                          +--------------------+-------------------+
                          |                    |                   |
                  Colab Job v0.3        HF Space Job          Windows Host
                  CLI-backed runtime    ZeroGPU API         VM / container adapter
                          |                    |                   |
                          +------- durable Storage Fabric artifacts +
```

**The MU is a coordinator, not an MI and not a placement authority.** Cloud accounts, Colab sessions and ZeroGPU Spaces are not advertised as always-on MI nodes. Provider capacity/eligibility is capability evidence with expiry, not a lease.

## State authority

- Upstream Job-to-Node owns `PLAN / ALLOCATE / CHECK / RENEW / RELEASE`, ownership epochs and capacity/lease fencing. The MU accepts exact lease evidence for verification by the upstream authority. It NEVER mints a lease.
- WLU Authority owns admission rights, accounting, settlement and quotas; MU gets an exact receipt check at admission and before provider launch.
- Storage Fabric owns durable input, checkpoint and output verification/commit. An external worker writing a file is not a durable result.
- Migratable Job owns migration, checkpoint/restart eligibility and retained live migration status, not the MU.
- QueueRexx peer mesh/Queue Fabric and Connect Selector own authenticated transport/routing. Avoid a new transport or a second peer-membership truth.
- The MU owns only provider execution intent, idempotency identity, ordered lifecycle state, provider recovery and cleanup. Observability does not grant execution authority.

## Submission/recovery invariants

`ACCEPTED -> ADMITTED -> STAGING -> SUBMITTING -> SUBMITTED -> RUNNING -> COMMITTING -> SUCCEEDED`

- `SUBMITTING` is synced **before** the first potentially effectful remote call. `dispatchKey = SHA256('mu-dispatch/1:' + jobId + ':' + request fingerprint)` is stable under a retried client request, but is not an authority token.
- Provider adapters must accept/retain the key, support exact idempotent lookup/reconciliation and prove a `remoteId` binding. Until this is qualified, live adapters remain absent.
- Exceptions during submit mark `UNCERTAIN`. Restarted `SUBMITTING` and `UNCERTAIN` can call only non-dispatching `reconcile(dispatchKey)`. If the provider cannot prove outcome, an authorised operator must resolve it. No blind re-dispatch.
- `STAGING`, `HELD`, `COMMITTING` and `UNCERTAIN` do not automatically re-dispatch. Staging recovery requires explicit examination of side effects; commit recovery requires Storage Fabric authority to establish whether the previous commit completed.
- `CANCEL_REQUESTED` is an observed control request, not a terminal state. Only provider status can prove `CANCELLED`. `LOST` denotes loss of liveness evidence, not proof of non-execution.
- `SUCCEEDED` requires a digest/size receipt and a successful Storage Fabric commit. The controller is not entitled to compute a digest from claimed provider metadata alone: verification remains with Storage Fabric.
- Admission and immediately-pre-dispatch checks are deliberately both required; a stale or revoked lease is not redeemed by earlier successful admission. Production worker start must additionally check exact ownership epoch/fence as close as possible to effect.

## Backend-specific constraints

**Colab.** `oorexx_colab_job_v0.3-dev1` owns CLI session creation, stage/install/execute/download/stop, secret retirement and artifact receipt verification. Work requires CPU/GPU/TPU; GPU/TPU must specify accelerator requirements. Requested resource does not imply observed capacity. Use installed CLI behavior as authority. Do not automatically retain sessions.

**ZeroGPU.** The HF Space operation is a managed, potentially shared/provider-throttled execution surface. It is not a GPU VM that the MU may promise to pin or checkpoint. Require explicit Space id, operation, entitlement and published API capability. Do not advertise guaranteed exclusive GPU time. Result handling and secrets remain under Space Job/Secret Broker.

**Windows.** GUI/application validation typically requires a Windows VM with explicit lifecycle, image provenance, licensing, update state and test isolation. Windows-kernel containers require an actual compatible Windows container host and pinned image digest. A Linux Docker daemon is insufficient. No Windows backend may implicitly copy credentials, mount arbitrary host volumes, enable broad network access or start an unapproved image.

## Limitations and deployment gates

The supplied reference controller holds one **local** advisory flock and records state in local files. This is not an HA control-plane, distributed ownership lease or production MI. Live promotion requires:

1. Verify current estate/revision of Job-to-Node network client and ownership fence under a real QueueRexx peer mesh and WLU entitlement.
2. Bind Storage Fabric by durable object id, output commit identity and recovery. Validate immutable input hashes and output hashes/size inside Storage Fabric.
3. Add typed, authorised provider adapters using the existing Colab Job/HF Space Job and Windows host lifecycle (not shell strings). Prove provider exact reconciliation keyed by the MU dispatch intent.
4. Integrate trusted credentials with Secret Broker; never journal bearer tokens or stage them through stdout, logs or ordinary environment fields.
5. Add real registration, health leases and routing through Connect Selector or authenticated mesh service registration; separate MU control from MI resource membership.
6. Test crash injection at every journal/side-effect boundary, multi-controller ownership fencing, quota exhaustion, provider rate limiting, cancellation races, stale status and restore after reboot.
7. Prove Windows host compatibility, image allowlist, licensing policy and teardown; run real canary workloads only with explicit live authorisation.

The test simulator is only valid for non-live acceptance; the code does not ship executable provider adapters.
