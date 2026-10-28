# Media Experiment Fabric Specification

API: `media.methodologies.experiment/0.1`

## Purpose

A media-processing experiment may contain many legitimate methodologies at once.
The experiment fabric exists to preserve those alternatives through distributed
execution and comparison. It is not an algorithm selector and it does not turn
agreement into truth.

## Scientific lineage

A **lineage** is the semantic methodology path being tested. Ten shards or ten
RexxOS nodes running the same methodology remain one lineage. Different
methodologies remain different lineages even when they process the same frames.
An explicit caller-supplied lineage id may separate materially different variants
of one methodology, but infrastructure fan-out alone never creates a new lineage.

## Planning

`MediaExperimentPlanner` expands every `MediaExperimentMethodSelection`
independently through the existing `MediaWorkShape` contract. Method-specific
halos, state hand-off and merge mode are preserved. No work unit in one lineage
is silently made a parent of another lineage.

The planner does not:

- select a RexxOS MI;
- allocate Memory Fabric;
- move Storage Fabric material;
- issue a Job-to-Node lease;
- execute a media implementation;
- merge reconstructed pixels or samples.

## RexxOS / Memory Fabric execution projection

`integrations/MediaExperimentFabric.cls` projects a work task into two existing
authority surfaces:

1. `MediaMethodologyMemoryFabricSession` for sparse/reference-first working-set
   access and adaptive horizon evidence; and
2. `MediaMethodologyJobNodeProjection` for the hard placement requirement.

Memory Fabric continues to own sparse backing, windows, cursor/horizon state and
movement demand. Job-to-Node continues to own placement/admission. RexxOS estate
membership remains discovery evidence and semantic node identity.

## Assembly

Shard outputs may be assembled only inside one lineage. The generic layer creates
`MediaExperimentAssemblyRequest`; an implementation-specific
`MediaExperimentLineageAssembler` must perform the actual merge because
`COLLECT`, overlap blending, state continuation, track-coordinate support merge
and similar modes are methodology semantics.

Cross-lineage assembly is rejected. Cross-lineage *comparison* is encouraged.

## Comparison

`MediaExperimentComparisonObservation` supports four relations:

- `AGREE`
- `DISAGREE`
- `INCOMPARABLE`
- `UNKNOWN`

Each observation names the metric/comparator and may carry a score plus an
independent evidence reference. The core does not define a universal image or
audio similarity metric.

`MediaExperimentComparison~winner` deliberately returns `.nil`. Selecting a
preferred candidate is a later policy/scientific decision and must never be an
implicit side effect of comparison.

## Reconstruction authority

Every reconstruction output remains a `CANDIDATE`. A candidate can carry:

- exact work-unit ancestry;
- methodology and implementation identity;
- support-map reference;
- uncertainty reference;
- execution provenance;
- output material reference.

No API in this package promotes reconstructed samples/pixels to captured source
evidence.
