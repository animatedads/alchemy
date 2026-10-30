# Changelog

## Repository continuation — 2026-10-29 peer source
- Add dev9 StoragePeer repair source resolver over existing StoragePeerClient/StoragePeerMaterialiser.
- Require explicit peer allowlist plus AVAILABLE+VERIFIED object-location evidence.
- Reverify StorageRef digest at resolver boundary.
- Mark staged peer materialisation temporary and remove it after destination provider store.
- Keep peer transfer separate from durable replica admission and destination selection.


## Repository continuation — 2026-10-29
- Add executable Storage repair destination planner contract.
- Add Git repair adapter over existing storage.fabric.git/0.1 post-push verification.
- Require policy gain before performance/locality preference can rank a repair target.
- Require digest-verified staged source before destination provider write.
- Define sourceResolver seam for Storage XTP / MU-MI materialisation without transferring replica-placement authority.
- Keep Job-to-Node out of durable replica repair destination choice.


## Repository continuation — 2026-10-27 worker binding
- Add Storage repair dev7 exact Queue Fabric dev6 CLAIM/ACK/NACK adapter.
- Preserve Queue Package claimToken/packageId as the only acknowledgement authority.
- ACK only after semantic repair succeeds; NACK semantic repair failure.
- Surface ACK failure after repair instead of manufacturing a retry path; replay remains safe through current-policy reassessment.


## Repository continuation — 2026-10-27
- Add fail-closed missing replica-policy doctrine: no implicit one-replica fallback.
- Record Instrumentation Mesh dev8 source candidate and producer-supplied-only correlation boundary.
- Record Storage dev24 standards FAIL as a release blocker rather than treating the label as canonical.
- Record dev23-precision1 as a precision/API compatibility overlay with stale internal version metadata and remaining house-rule violations.
- Add Storage Fabric Instrumentation Mesh dev6 compatibility/release gates.


## Repository continuation — 2026-10-23
- Add durable replica-repair/topology-reconciliation doctrine grounded in Storage Fabric dev23 API names.
- Record post-authority-commit reconciliation, provider-scoped affected-object scanning, persistent Queue Fabric repair work and replay-safe current-policy re-assessment.
- Record TEMPORARY != DISPOSABLE, OFFLINE != LOST, Instrumentation Mesh observation-only authority, and Git verification-before-admission invariants.
- Pin the Storage Fabric Instrumentation Mesh dev5 source-qualified adapter archive and its static-only qualification boundary.
- Preserve v0.3 sphere identity because the project catalog still points to v0.3 while the active resolver selects a local v0.6 override; do not manufacture a replacement for unavailable newer complete sphere source.

## v0.3 — 2026-09-06
- Rebase authority to Storage Fabric v0.1-dev7.
- Add stable node identity versus provider/endpoint doctrine.
- Add observed block-device versus explicit workspace/durable admission doctrine.
- Add Storage fleet matrix semantics: per-node storage feasibility/movement evidence without taking Job-to-Node ranking/lease authority.
- Record current ED209 test fleet identities and the Azure trial workspace lifecycle boundary.
- Prove unqualified Azure devices and unknown AWS capacity are not invented into planner capacity.

## v0.2 — 2026-09-06
- Rebase authority to Storage Fabric v0.1-dev6.
- Add provider-authoritative resume reconciliation and partial acknowledgement doctrine.
- Add Google Drive bounded HTTP/auth/range/resumable source/sink, remote SHA-256 verification and API Client v0.3 bridge continuity.
- Add provider-capability/auth secrecy article: bearer tokens and resumable-session URIs never enter generic Storage evidence.
- Record BashQueues Drive account as disposable TEST qualification storage.

## v0.1 — 2026-09-05
- Initial Storage Fabric architecture/continuity sphere.
