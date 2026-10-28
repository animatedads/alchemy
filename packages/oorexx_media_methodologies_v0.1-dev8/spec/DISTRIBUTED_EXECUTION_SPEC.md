# Distributed Media Methodology Execution Specification

## 1. Purpose

Media Methodologies deliberately describes many competing processing techniques.  A serious processing run may therefore execute several independent methods, several implementations of the same method, or a large reconstruction over many temporal/spatial windows.  This specification defines how those semantics can be turned into distributed work without making the methodology catalogue itself a scheduler.

The execution API is `media.methodologies.execution/0.1`.

## 2. Authority boundaries

The layers are intentionally separate:

- **Media Methodologies** owns method semantics, work-shape hints, reconstruction/evidence status and composition rules.
- **Provider implementations** own their real runtime/hardware/resource requirements.
- **Memory Fabric** owns sparse logical backing, resident windows, cursor/horizon state, block generations and movement demand.
- **RexxOS Grid** owns current MU/MI estate membership and observed node profile evidence.
- **Job-to-Node** owns hard eligibility, admission and placement leases.
- **Storage Fabric** owns durable material identity/locality/workspace facts.

A media planner may project requirements into those authorities; it must not reimplement their decisions.

## 3. Methodology work shape is not hardware requirement

Each methodology has a `MediaWorkShape` describing the *shape* of safe decomposition:

- shard axis (`FRAME_RANGE`, `SAMPLE_RANGE`, `TIME_RANGE`, `SOURCE_SET`, `NONE`);
- state model (`STATELESS`, `WINDOW_STATE`, `TRACK_STATE`, `GLOBAL`);
- source access pattern;
- pre/post halo size;
- merge semantics;
- continuity requirement;
- materialisation preference.

This belongs to the methodology semantics because it states what evidence must overlap for a valid calculation.  It does **not** say that a GPU, FFmpeg, Python, CUDA or a particular amount of RAM is mandatory.

Hardware/runtime requirements belong to `MediaImplementationExecutionProfile`, which is provider-specific.

## 4. Windowing and halos

A work unit contains two ranges:

- **core range** — output authority belongs to this unit;
- **read range** — core plus required temporal/sample halo.

Neighbouring workers may therefore read overlapping source material while emitting non-overlapping core output.  This avoids seam artefacts and preserves finite-context methods.

Stateful methods need more than overlap:

- `WINDOW_STATE` permits independent window state with overlap/blend;
- `TRACK_STATE` requires identity/state handoff or later track stitching;
- `GLOBAL` must not be naively split merely because compute nodes are available.

## 5. The leading-edge blur reconstruction

`VIDEO.RECON.LEADING_EDGE_BACKPROJECTION` is specified as:

- shard axis: `FRAME_RANGE`;
- state model: `TRACK_STATE`;
- default halo: 8 frames before and after;
- continuity: `STATE_HANDOFF_REQUIRED`;
- merge: `TRACK_COORDINATE_SUPPORT_MERGE`.

A long clip can therefore be processed in overlapping windows on several MIs.  Each worker may detect/score supported leading/trailing edge strips in its read range, but it emits authoritative reconstruction support only for its core range.  Track/trajectory identity is carried across boundaries.  A final merge combines source-supported strips in canonical track coordinates, followed by the separately specified forward re-blur validation.

The distributed execution does not make the experimental method less experimental.  It only makes a larger experiment practical.

## 6. Multiple methods and independence

Parallelism is not limited to cutting one algorithm into pieces.  The catalogue is explicitly designed for branch parallelism:

- leading-edge backprojection;
- bidirectional blur-envelope reconstruction;
- blind/multi-frame deconvolution;
- flow-warp accumulation;
- strip mosaic;
- temporal occlusion reveal;
- model-assisted reconstruction.

These may run on different nodes and produce separate `MediaReconstructionCandidate` objects.  Consensus must retain implementation lineage.  Five workers running the same implementation/model are not five independent methods.

## 7. Placement

The media layer may construct a `JobPlacementRequest` from an implementation profile.  It may not select a node itself.  Required runtime, abilities, legal/trust domains, architecture, minimum resources and WLU rate remain hard requirements when handed to Job-to-Node.

RexxOS MI membership is discovery evidence only.  A current MI is not automatically eligible for a workload.

## 8. Failure and restart

Work output should be reconstructable where practical.  Large transient decode buffers and optical-flow caches should normally be `RECONSTRUCTABLE`; irreplaceable annotations or expensive intermediate candidates may be `CHECKPOINTED` or durable Storage Fabric material.

Restart must retain:

- source/material reference;
- methodology and implementation identities;
- exact core/read range;
- parameters;
- coordinate/time transforms;
- placement lease reference where applicable;
- Memory Fabric object/epoch/generation references;
- parent work-unit identities.

