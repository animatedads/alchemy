# Reconstruction Method Specification

## 1. Why reconstruction is a first-class family

A damaged or information-poor observation is not necessarily useless. Multiple frames, multiple microphones, different viewpoints, exposure blur, occlusion changes, rolling-shutter timing and physical coupling can all provide complementary constraints on a latent event or object.

The catalogue therefore includes reconstruction methods on purpose. The governing rule is not “never reconstruct”; it is **never confuse reconstruction with observation**.

## 2. Reconstruction output contract

A reconstruction should produce, where applicable:

- the reconstructed candidate;
- source references;
- decoded/source-relative time interval;
- coordinate system and transforms;
- support map or support count;
- synthetic/prior-driven mask;
- uncertainty map/distribution;
- method and implementation identity;
- parameters;
- forward-model residuals;
- controls and competing-method results.

Unfilled regions are preferable to plausible invention when the goal is evidential reconstruction.

## 3. Experimental leading-edge motion-blur backprojection

Method ID: `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION`

### 3.1 Motivation

Consider a person walking into a camera view. There may be no sharp still frame: the subject is motion-blurred in every exposure. Even so, the blur does not contain zero information. As the person moves, each exposure can reveal a different boundary of subject support.

The useful intuition is that the **leading motion-blur envelope can be a higher-confidence constraint** than the blurred interior because it is the boundary where previously empty/background support begins to receive subject contribution.

That does not make the front edge an instantaneous photograph. A conventional exposure integrates radiance over an interval. The exact edge location depends on shutter function, subject motion, camera motion, defocus, rolling shutter and contrast. The method therefore treats the edge as supported evidence with uncertainty.

### 3.2 Candidate algorithm

1. Decode frames on the source PTS timeline.
2. Establish camera state. Remove/represent global camera motion or withhold the method while geometry is uncontrolled.
3. Estimate subject motion direction/trajectory over a bounded temporal window.
4. Estimate a blur support vector or PSF family per frame.
5. Detect candidate leading and trailing support boundaries. Preserve both; do not assume direction merely from gradient sign.
6. Score boundary strips using edge strength, continuity, temporal persistence, local blur width, occlusion state and agreement with neighbouring frames.
7. Transform accepted strips into a canonical object/track coordinate system.
8. Accumulate only pixels/samples with identified source support. Record the contributing frame, time and weight for each output region.
9. Leave unsupported interior unresolved, or route it to a separate explicitly synthetic inpainting methodology.
10. Forward-project/re-blur the candidate through each frame's estimated motion/PSF and compare with the observed frames.
11. Run controls: trailing-edge reconstruction, time-reversed sequence, parameter sensitivity and at least one independent reconstruction method.
12. Emit a `MediaReconstructionCandidate`, support map, uncertainty map and residual report.

### 3.3 Where it can work

It is most promising when:

- motion is monotonic for several frames;
- subject/background contrast is adequate;
- camera motion is absent or well estimated;
- blur direction is coherent;
- successive frames expose genuinely new portions of the moving subject;
- occlusion is limited;
- the shutter/readout model is known or estimable.

### 3.4 Where it fails or becomes weak

Expected failure modes include:

- acceleration or reversal causing “leading” and “trailing” semantics to change;
- subject rotation or articulated deformation;
- strong defocus mixed with motion blur;
- rolling shutter without row-time correction;
- overlapping moving objects;
- saturated highlights;
- low-contrast/textureless boundaries;
- compression ringing masquerading as edge support;
- foreground/background occlusion;
- too few distinct observations.

A partial reconstruction is an acceptable result. “Could not recover interior texture” is scientifically better than filling it by assumption.

## 4. Related reconstruction methods

The leading-edge method should rarely run alone. The catalogue also specifies:

- known-PSF deconvolution;
- blind deconvolution;
- defocus deblurring;
- multi-frame latent sharp reconstruction;
- multi-frame super-resolution;
- optical-flow warp-and-accumulate;
- trajectory-aligned stacking;
- bidirectional blur-envelope reconstruction;
- motion-blur trajectory tomography;
- moving-object strip mosaic;
- temporal occlusion reveal;
- temporal background reconstruction;
- rolling-shutter slice reconstruction;
- temporal frame interpolation;
- temporal inpainting;
- multi-view texture fusion;
- silhouette/visual-hull reconstruction;
- audio declipping/dropout repair/spectral repair;
- room-response deconvolution;
- blind acoustic deconvolution;
- visual microphone reconstruction.

## 5. Forward-model validation

A reconstruction method should be tested in the direction opposite to reconstruction.

For a deblurred video candidate, reapply the estimated blur and motion. For a super-resolved candidate, downsample through the declared sampling model. For declipped audio, reclip at the known threshold. For a dereverberated waveform, convolve with the estimated room response.

A candidate that cannot reproduce the actual observation under its own forward model is weak evidence even if it looks attractive.

## 6. Multi-method consensus

`AV.RECON.CONSENSUS` compares independent candidates in a common coordinate/time frame. It outputs both agreement and disagreement maps.

Consensus is not majority voting. Three methods that share the same optical-flow estimate may have a common-mode failure. Provider/assumption lineage is therefore part of comparison.

## 7. Synthetic fill boundary

Inpainting, learned super-resolution, bandwidth extension and learned audio super-resolution are allowed. Their synthetic regions must be marked. Those regions are useful for visualization, listening and hypothesis generation but cannot establish unobserved letters, faces, phonemes, object markings or other fine factual detail by themselves.
