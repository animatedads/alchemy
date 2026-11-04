# ED209 RTO2 Grid Gopher Sphere v0.3

This sphere records implementation boundaries, field evidence, controller design, cross-authority integration and acceptance criteria for the ten-MU / twenty-MI RexxOS ED209 Grid.

Use `gopher --profile ed209-rto2-grid context ed209-rto2-grid --full` after installing the sphere profile and pack.

**Status:** the generic RexxOS RTO2 Grid controller is evidenced through `rexxos_rto2_grid_v0.1-dev14` with first-class MU/MI objects, read-only estate service publication and explicit authority boundaries. The ED209 field estate is larger: ten MUs and twenty MIs. Candidate2 and the F/H commissioning work remain field evidence, and there is still **no confirmed live 20/20 RTO2 run** and no accepted latest-XTP end-to-end ten-MU deployment.

## Current controller boundary

- The generic dev14 controller proves a minimum reference estate of 8 MUs + 16 MIs. It is a reusable controller substrate, **not** the complete ED209 topology.
- ED209 extends that substrate to ten MUs + twenty MIs. Do not collapse the field topology back to the generic 8/16 minimum.
- MU and MI are first-class ooRexx estate objects. An MU is not implicitly a compute slot; managed execution targets are not automatically MIs.
- The Grid controller owns estate identity, MU/MI membership and observation projections. Job placement, WLU admission, Storage residency, Memory allocation, XTP path selection, economic ranking, cloud purchase, transport selection and serialization selection remain separate authorities.
- The dev14 estate service is read-only and is published through RpcServiceCore; ConnectSelector owns DirectCall/RPC/Queue route choice.

## Transport and field boundaries

- Existing registered Queue Fabric over segmented XTP transports actual work. SSH through `sshnode.sh` is operator management of the owning MU only, not a substitute for MI job dispatch.
- Native XTP named-service identity comes from Service Descriptor Registry in FIRST, not port numbers or receiver-channel strings; later KEY/DATA belongs to the admitted context.
- MI↔MU uses L2 EtherType 0x817D; non-Google MU↔MU native IPv4 protocol 36; Google-involving MU↔MU encapsulated UDP 62801.
- Queue Fabric transport acknowledgement, RTO2 captured/committed state, Storage Fabric durable commit, Migratable Job lease and Job-to-Node allocation are different authorities.
- Preserve proven F/H guest FAST crypto, boot registration and L2 TAP return paths; no blind replacement of installed private authority.

## Current integration line

- `job_node_allocator_v0.6-network6` remains the placement/lease authority; its package records network6 runtime qualification as pending.
- `cloud_economics_v0.1-dev8` supplies advisory economics and migration evidence, never allocation or buying authority.
- `rexxos_managed_compute_mu_v0.1-dev2` is an integration candidate for managed external execution. Production dispatch remains disabled until durable replay/request handling, atomic claim/provider idempotency and RTO2 membership-generation revalidation are complete.
- Placement-layer and remote-compute spheres remain sibling authority records; this sphere records how RexxOS consumes them without absorbing their authority.

## Provenance

- `rexxos_rto2_grid_v0.1-dev14.zip` SHA-256 `693a5e4d696790d10e1c366c77849514918ca558510cbf696189442f464b0e0a`
- `ed209_rto2_20mi_candidate2_managed.zip` SHA-256 `940ee1835f9dd53ceea42a14e0eb7880e4dc374d6813cfbc686972debe23b4e1`
- `rexxos_managed_compute_mu_v0.1-dev2.zip` SHA-256 `82a02b1d0206ca6f1d05eadb47a108b2475074c6f18a9ea5a4a54af221229ecc`
- `cloud_economics_v0.1-dev8.zip` SHA-256 `8354043fc133ef9b6fdb593ec8d000e278e0748228224464b9ebb7feb485e735`
- `job_node_allocator_v0.6-network6.zip` SHA-256 `d26153c6f5a70fb8979be34b231d4716d1eb60e8dec4292d89bedc1487b09fe2`

## Acceptance gate

A single run ID must produce twenty distinct authenticated and locally committed RTO2 receipts, one from each assigned MI route, all computing `500500`. Missing one is FAIL; a synthetic fixture is not a live result. The ten-MU estate must also preserve native MU identity and exact membership generation while proving the current admitted XTP service path on the carriers actually used by that route.

Tracking: https://github.com/animatedads/alchemy/issues/17

## 27 October 2026 reconciliation

Library source now includes `rexxos_rto2_grid_v0.1-dev15.zip` (SHA-256 `e94ba156182567752e7e3b86e88b6a0e8a25fb8710648bb373a4c33271226543`), `oorexx_memory_fabric_xtp_candidate4.zip` (SHA-256 `3ef13e7cc66a69f684d601d5bd275c926c8580bb0f07a41119544ab8f0326e40`), and `queue_fabric_xtp_receipt_gate_v0.1_candidate1.zip` (SHA-256 `9a33b2df21d436639de3ba5f2ef17c97bd04ddbdf51c8eb7dd735a40281da032`). These are distinct upstream candidate lines, not evidence of a live 20-MI deployment.

On connected GitHub main, XTP dev30 is present. CODEX-PC's read-only RTO2 review of 27 October (Rasen Falcon REQ-00000513) established that the ED209 candidate2 submitter still uses the older QFXTP segmented path. Main's generic RTO2 estate controller v14 8-MU/16-MI reference and Library dev15 should not be conflated with the 10-MU/20-MI field estate.

R-11 diagnostic source correction was built, locally checked, and submitted on `autobuild-submit/20261027T180300Z-CHATGPT-ed209-rto2-candidate3-r11-a6c42f`. 4/4 new shell wrapper tests, 6/6 image preflight and 2/2 additive overlay tests passed locally. The full legacy 20-MI synthetic rerun stalled; live 20/20, R-10 signed MI-origin attribution, and F/H reboot recovery remain unaccepted. See `ed.review20261027`.
