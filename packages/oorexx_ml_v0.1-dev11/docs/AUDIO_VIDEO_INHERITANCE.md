# Audio/video inheritance into ooRexx ML

## Layered Audio

The existing Layered Audio line already establishes several generic ML rules:

- typed model specifications and tensor descriptors;
- semantic materials separate from runtime tensors;
- provider-neutral execution;
- streaming processors with NONE / CHECKPOINTABLE / provider-affine state;
- value-only state checkpoints for offload;
- precision and quantization as explicit policy/evidence;
- results returning as materials plus provenance rather than opaque runtime handles.

The ML package adopts those principles. It does not yet move Audio's generic class names because Layered Audio v0.21 currently defines them and class collisions would prevent co-loading. `MLModelDefinition` and `MLTensorContract` provide the temporary upward-migration seam.

## Camera Behaviour

Camera Behaviour v0.56 supplies the strongest learned-state precedent:

- `CameraLearnedGeneration` freezes a complete learned world;
- the registry retains superseded generations;
- materialised state snapshots remain stable while the live model changes;
- source barriers prevent learned nuisance/scene state from leaking across a genuine source discontinuity;
- coarse behavioural primitives and outliers remain evidence, not identity claims.

The ML equivalents are `MLLearnedGeneration`, `MLLearnedGenerationRegistry`, `MLLearningBarrier` and `MLAssessment`.

## Project Shuffle / Shuttle

The forensic media line supplies operational discipline:

- originals are never overwritten;
- derived outputs retain source windows and sidecars;
- policies/manifests make reruns reproducible;
- uncertainty is explicit;
- AI classifications are advisory and policy controls destructive action;
- human review queues preserve the distinction between candidate evidence and accepted labels/claims;
- strongest conclusions come from convergence across independent evidence types.

Future ML review/label objects should preserve this pattern rather than making `predict()` an authority boundary.

## Shared future

Longer term, Audio and Camera should depend on common ML contracts rather than each owning generic ML vocabulary. The migration must be staged so existing packages remain loadable and qualification evidence is not broken.

## dev2 generalisation

The dev2 training/validation layer makes two more media lessons generic:

- Camera/Shuffle source identity becomes `MLDatasetProvenance` plus stable sample identities and explicit derived train/test/fold datasets.
- Audio streaming's “state is separate from semantics, but sufficient state must travel for continuation” becomes coordinated model/optimizer/session State-of-the-Nation checkpoints.

The new `MLBranchComparator` also mirrors forensic media practice: two analytical futures can be compared against the same source evidence without replacing the live source or silently promoting either result into an authority claim.
