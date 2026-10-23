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
