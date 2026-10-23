# Perception Library and Services — portable compute (development)

This is a separate, provider-neutral component family for facial landmarks, pose, hands, object detection and segmentation. It is **not** a Google-specific interface or a replacement for Vision.

## Boundaries
- Perception Library owns method/capability descriptions and typed observation provenance.
- Perception Service owns discovery and portable work preparation.
- Compute Layer and Job-to-Node own eligibility and placement.
- Migratable Job owns execution lease/epoch, fencing, checkpoint and migration.
- Storage Fabric owns input pin, materialisation lease and durable output commit.
- Queue Fabric status is observational, never an execution lease.
- Foreign Runtime is the existing ooRexx-to-Python implementation seam.

No node-local paths or credentials may appear in durable work. The pinned source, model, temporal window, coordinate conventions, algorithm version and checkpoint format survive MU migration. The destination must independently satisfy access, legal-region, hardware and model requirements. Model substitution requires explicit requalification.

## Current maturity
The portable Python reference contract is implemented and tested separately. This repository branch introduces the integration specification and the independently testable reference admission module. Live Compute Layer / MI-MU dispatch, ooRexx runtime binding and MediaPipe/MMPose/ONNX execution are **not** claimed.

See [contract](spec/portable-work.md).
