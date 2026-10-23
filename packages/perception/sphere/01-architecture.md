# Perception Library and Services — engineering sphere

**Revision:** 0.1-dev1, 2026-10-23. **Status:** draft, not an accepted runtime sphere.

## Intent and ownership
Reusable perception capabilities for facial mesh, body pose, hand landmarks, object detection and segmentation. The library describes observations, capabilities, coordinate spaces, models and source-time provenance. It must operate independently of Google/MediaPipe and independently of Alchemy orchestration. MediaPipe Tasks, ONNX Runtime, MMPose, OpenPose and other engines are alternative implementations, not semantic authorities.

The Perception Service discovers eligible providers and prepares transport-neutral operations. Vision and Media Methodologies consume results and retain their own interpretation. A face mesh does not identify a person.

## Portable execution
Perception jobs are defined without MU identity or local filesystem paths. Immutable identity binds source StorageRef, generation, digest, source-global PTS interval, operation, model digest, processing options and checkpoint schema. Job-to-Node checks eligibility and legal region. Compute Layer provides execution resources. Migratable Job controls lifecycle, leases, fencing and migration. Storage Fabric pins/materialises source and commits results durably. Queue Fabric status is observational only.

No admission projection may confer execution authority. No source/model replacement may be silently accepted during migration. Stateful tracking requires checkpointable temporal continuation; stateless frame inference may be partitioned independently. Remote timeout alone never relinquishes the lease.

## Interfaces and isolation
- Library: capability descriptor, provider registry, observation envelope, provenance.
- Service: discovery, work preparation, result validation, no scheduler.
- Provider: host-specific runtime adapter and model runner through existing Foreign Runtime when Python is used.
- Execution: existing MI/MU Compute Layer and Migratable Job contracts, never a second dispatcher.
- Storage: pinned input and durable output, never a path embedded in work identity.
- Intention Service: dynamically available capabilities; unavailable methods must be UNKNOWN/BLOCKED, not fabricated.

## Relationship to existing work
The 2026-10-13 Video Analysis Mesh has a source-pinned full-face-mesh worker candidate and source PTS conventions. Customer Service Face Pipeline provides MediaPipe candidate and Google/Azure transcript normalization. These are integration sources, not claims of production-ready multi-person tracking. Media Methodologies owns method/experiment lineage, not execution authority.

## GitHub implementation
`packages/perception/src/portable_admission.py` is an advisory capability matcher with tests. It is not a live Compute Layer adapter. The previous perception-compute development archive has not been imported wholesale. GitHub PR #21 is draft.
