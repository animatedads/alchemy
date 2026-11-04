# ooRexx Storage Fabric LLM Gopher sphere v0.3

Authoritative continuity/documentation sphere for ooRexx Storage Fabric. It remains separate from executable Storage Fabric packages.

v0.3 advances the grounding baseline to `oorexx_storage_fabric_v0.1-dev7.zip` and adds durable doctrine for node identity, provider/endpoint separation, block-device observation versus admission, and per-node storage-feasibility matrices across the ED209 test fleet. It preserves the v0.2 provider-authoritative resume, partial acknowledgement, Google Drive bounded transfer, API Client bridge and capability-secrecy doctrine.

It also retains the established object/location/path/policy split, EA/query folders, TVFS-style union/search views, fluid aliases, LIVE/TEST/DEVELOPMENT overlays, capacity-domain reservations, removable media, measured performance, disposable-service safety and job-to-data/data-to-job locality doctrine.

Start with:

    gopher --profile storage-fabric context storage-fabric --full
    gopher --profile storage-fabric open arch.storage-fabric.node-inventory
    gopher --profile storage-fabric open arch.storage-fabric.provider-capability-security
    gopher --profile storage-fabric search "device admission" --sphere storage-fabric
    gopher --profile storage-fabric search "job to data" --sphere storage-fabric
    gopher --profile storage-fabric search disposable --sphere storage-fabric

Current executable grounding baseline:

    oorexx_storage_fabric_v0.1-dev7.zip
    SHA-256 5a74891b868d91ba14ac4fe1fb9e02c1faaa203948aed0fa652c7cfb1473a09f


## 2026-10-23 Storage named-service admission doctrine

Added `arch.storage-fabric.service-admission` to the GitHub projection of this sphere, covering socket neutrality, FIRST/KEY context verification, no-downgrade, multicast hints and durability authority. An earlier repository note described a later full sphere as v0.7. In the 2026-10-23 reconciliation, the active resolver could be verified only to a local v0.6 override and Library search did not independently resolve a v0.7 artifact. Treat v0.7 as unverified historical continuity until its exact artifact is recovered; do not manufacture a replacement by overwriting this older repository projection.

## 2026-10-23 durable replica repair / topology reconciliation continuation

Added `arch.storage-fabric.replica-repair-reconciliation` to this older GitHub projection. It records the dev23-compatible repair contract: Storage commits provider/location state first; affected objects are re-assessed against their current persisted replica requirement; real deficits become persistent Queue Fabric work; and workers re-assess before movement so stale/replayed repair safely becomes a no-op when protection has already recovered.

This continuation also records the hard semantic separations established by later Storage work: TEMPORARY is not DISPOSABLE, OFFLINE is not LOST, placement preference is not durability authority, Git push is not replica admission, and Instrumentation Mesh is observation rather than safety authority.

Repository/catalog note: the project catalog still identifies this v0.3 sphere projection, while the active LLM Gopher resolver currently selects a local v0.6 override. This commit therefore updates v0.3 in place as a repository continuity projection; it does not claim to reconstruct, supersede or re-publish the unavailable complete newer sphere source.


## 2026-10-27 protection-policy and release-line reconciliation

The repair adapter now has a dev6 continuation. Missing replica policy is not
interpreted as `StorageReplicaRequirement(1)`: it is a fail-closed
`policy_missing` state unless a policy owner explicitly injects an estate
fallback. This prevents an absent policy record from silently weakening
recoverability.

The estate Instrumentation Mesh source candidate is dev8, SHA-256
`47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`.
Its explicit correlation/causation/context capability does not change Storage
authority: correlation is producer evidence and must never be inferred from
timestamps, hosts, StorageRef similarity or payload content.

Storage release labels are not sufficient promotion evidence. The Library
dev24 standards report is FAIL and does not prove that dev23, the networking
candidate line and dev22(1) large-file/canonical-integer fixes were coherently
merged. The Git `dev23-precision1` overlay demonstrates `::options digits 30`,
canonical unsigned helpers and the current replica API, but its stale internal
version metadata and remaining house-rule violations keep it an overlay
candidate rather than a canonical release.


## 2026-10-27 exact Queue Fabric repair worker

The current Queue Fabric dev6 contract was inspected directly. Storage repair now
has an exact adapter for `claim(queue, principal)` followed by
`ack(queue, packageId, claimToken, principal)` or `nack(...)`. The Queue
Package itself supplies the package ID and claim token. Correlation IDs and
repair IDs are never substituted for Queue Fabric claim authority.

Successful semantic repair is ACKed once. Failed repair is NACKed for Queue
Fabric's existing retry/backout/dead-letter semantics. If ACK fails after Storage
has already satisfied the repair, the adapter reports `ACK_FAILED_AFTER_REPAIR`
and does not guess at a second control action; safe replay relies on the repair
boundary's current-policy reassessment.


## 2026-10-29 executable repair destination planning

Storage repair now has an executable destination-planning seam rather than an
opaque `planner~repair` placeholder. The planner is strictly Storage-owned:
it evaluates durable replica count plus vendor/site/failure-domain improvement,
then delegates bytes to a provider adapter. Job-to-Node remains execution
placement authority and is not called by replica repair.

The first concrete destination adapter is the existing Git/Azure-capable
`storage.fabric.git/0.1` provider. Git/Azure speed may contribute only as an
injected preference tiebreaker after policy improvement has been established.
The provider's post-push verification must return a durable verified
`StorageLocation` before admission.

Source acquisition is a separate verified-materialisation resolver. This is the
integration seam to Storage XTP named-service networking: MU/MI transport may
materialise the exact StorageRef to a local staged path, but it does not select
the repair destination or admit the replica.


## 2026-10-29 verified StoragePeer repair source

Dev9 closes the repair source side using the existing Storage peer contract rather
than adding another network stack. `StoragePeerRepairSourceResolver` consumes
`StoragePeerClient` and `StoragePeerMaterialiser`; peers must be explicitly
allowlisted and represented by current AVAILABLE+VERIFIED object-location
evidence.

The peer materialiser independently SHA-256 verifies the full StorageRef before
publishing the staged path. The resolver validates the digest again and marks
the source temporary. After the destination provider consumes it, the repair
planner removes the staged source. The temporary peer materialisation is never
promoted into a durable replica merely because transfer succeeded.

This is the concrete consumer seam for MU↔MI Storage networking. XTP named
service admission and carrier selection remain owned below `StoragePeerClient`;
repair code contains no L2/raw36/UDP/IP/port authority.
