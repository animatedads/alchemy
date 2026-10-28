# Media Methodologies Architecture

## 1. Problem statement

Media processing has no universally correct algorithm. The correct technique depends on the observation process, the available source material, the scientific question, the coordinate/time authority, and what kinds of failure are acceptable.

The architecture therefore treats a processing method the same way a robust intention system treats a possible intention/provider: as a **registered methodology with explicit semantics**, not as hard-coded global truth.

The catalogue is open-world. New providers may register new methods at runtime. Existing methods may have several independent implementations. Planning is performed against the evidence that exists *now* rather than a permanently cached preferred algorithm.

## 2. Methodology is not implementation

A `MediaMethodologySpec` describes what a method means:

- ID and human name;
- domain and family;
- maturity (`ESTABLISHED`, `QUALIFIED_PATTERN`, `EXPERIMENTAL`, `MODEL_ASSISTED`, `FORENSIC_CAUTIOUS`);
- authority effect (`PRESERVE`, `MEASURE`, `RECONSTRUCT`, `HYPOTHESIZE`, `VISUALIZE`);
- whether it is experimental;
- whether it reconstructs unobserved/latent material;
- principle;
- required input kinds and output kinds;
- assumptions;
- failure modes;
- required controls;
- allowed and forbidden claims;
- composition tags.

An implementation provider is a separate object/package. Several providers may implement one methodology, and one provider may implement several methodologies.

## 3. Evidence ladder

The package defines a strict authority ladder.

### 3.1 Source observation

Bytes/samples/decoded frames with source identity and source-relative timing. These are never rewritten as a result of processing. Corrective transforms produce a *derived* representation and retain the source.

### 3.2 Derived measurement

A value calculated from source observations: optical flow, line support, TDOA, spectral energy, subpixel door movement, vanishing points, etc. The measurement may be wrong; provenance and uncertainty remain attached.

### 3.3 Reconstruction candidate

An estimate of latent or missing material: a deblurred appearance, super-resolved image, restored clipped waveform, temporal mosaic, visual-microphone waveform, etc. Reconstruction is useful, but it is not a captured observation.

`MediaReconstructionCandidate` is deliberately fixed at status `CANDIDATE`. The API provides no operation that turns it into a source observation.

### 3.4 Hypothesis

A semantic or physical interpretation: source location, depth, event type, acoustic coupling, camera path, speech transcript, etc. Hypotheses require independent support appropriate to the claim.

### 3.5 Visualization

A view made to help a human see a pattern: contrast enhancement, Eulerian magnification, acoustic heat map. Visualizations are not additional evidence.

## 4. Reconstruction discipline

Every reconstruction method must answer five questions:

1. **What observations support each output element?**
2. **What forward observation model is assumed?**
3. **Which parts are constrained and which are prior-driven/synthetic?**
4. **How sensitive is the result to parameters and alternative methods?**
5. **Can the reconstructed candidate reproduce the source when run through the forward model?**

Where feasible, reconstruction outputs contain a per-pixel/per-sample support map and uncertainty map. A pixel assembled from frame 101 is distinguishable from a pixel invented by an inpainting model.

## 5. Experimental is first-class

`EXPERIMENTAL` means “useful enough to specify and test, but not established enough to assume reliable outside its qualified envelope.” It does not mean “forbidden.”

Experimental methods are expected to fail sometimes. Their specification must make the failure useful by reporting:

- why the preconditions were or were not met;
- how much source support exists;
- where the candidate is uncertain;
- which controls were run;
- whether an independent method agreed.

A policy may exclude experimental methods in a conservative production run, but the default research catalogue permits them.

## 6. Plural planning

A media goal normally yields **a set of candidates**, not a single winner.

For example, “recover detail from a blurred walking subject” may legitimately plan:

- leading-edge motion-blur backprojection;
- blind deconvolution;
- multi-frame latent sharp reconstruction;
- optical-flow warp-and-accumulate;
- moving-object strip mosaic;
- multi-frame super-resolution;
- forward-model reprojection qualification;
- cross-method disagreement preservation.

These methods are not equivalent. Agreement raises confidence only to the extent that their errors are independent. Disagreement is retained.

## 7. Dynamic discovery

`MediaMethodologyCatalogue~registerProvider()` and `~refreshProviders()` provide the open provider seam. A caller can refresh providers before planning so that newly available native libraries, devices, models, calibration data or remote workers can offer additional methodologies.

This should not become a static “method X always handles goal Y” table.

## 8. Time and coordinate authority

Every method that uses time states which clock it consumes. Every spatial method states which coordinate system it consumes and emits.

Examples:

- decoded video PTS;
- decoded audio sample time;
- camera wall-clock mapping;
- source pixel coordinates;
- Vision lattice coordinates;
- track coordinates;
- Photo World / reconstructed world coordinates.

Transformations between those systems are explicit evidence objects, not implicit arithmetic in downstream code.

## 9. Missing evidence is not negative evidence

If a camera is moving, an ROI is occluded, a microphone clips, a source is outside the beam, or a required calibration is absent, the system reports **unavailable authority**. It does not silently convert absence of usable observation into “nothing happened.”

This rule applies equally to audio and video.

## 10. Model-assisted methods

Learned denoisers, super-resolution, monocular depth, source separation, ASR and related methods are valuable providers, but model output carries model identity and model-domain assumptions.

Model-generated fine texture, missing phonemes, inferred depth or inpainted pixels never acquire source-observation authority merely because they look plausible.

## 11. Storage boundary

Large media should remain behind source/material references. Methodology plans and evidence objects should move identities, regions, timestamps, transforms, measurements and hashes through the control plane. Selective high-resolution AOI requests can retrieve the smallest authoritative source material necessary for a method.

## 12. Versioning

Method IDs describe semantics and should remain stable when an implementation changes. A semantic change gets a new method ID or methodology API version. Implementation/package identity belongs in provenance, not in the methodology ID itself.
