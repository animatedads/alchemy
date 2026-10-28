# Worked example — distributed blurred-subject reconstruction

Assume frames 1..300 contain a person entering the scene, blurred in every frame.

`VIDEO.RECON.LEADING_EDGE_BACKPROJECTION` uses 100-frame core windows with an 8-frame halo:

| Work | Core output | Read range |
|---|---:|---:|
| #1 | 1..100 | 1..108 |
| #2 | 101..200 | 93..208 |
| #3 | 201..300 | 193..300 |

The overlap is read support, not duplicate output authority.

Each worker:

1. resolves the source material reference;
2. opens a Memory Fabric cursor for its read window;
3. adapts the event horizon from observed decode rate and transfer latency;
4. estimates camera/subject motion and leading/trailing edge support;
5. emits source-supported strips only for its core range;
6. records uncertainty, support and forward-model residuals.

Track-state handoff/stitching then unifies the three windows in canonical track coordinates.  The merged reconstruction remains a **candidate**, after which `QUAL.FORWARD_MODEL.REPROJECTION` re-blurs it and compares it to the actual frames.

The same source can simultaneously feed other methodology branches through independent Memory Fabric cursors.
