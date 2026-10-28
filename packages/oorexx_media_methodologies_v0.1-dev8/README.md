# ooRexx Media Methodologies v0.1-dev8

API family now additionally includes:

- `media.methodologies.audio-v9-provider/0.1`
- `media.methodologies.audio-v9-physics/0.1`
- `media.methodologies.instrumentation/0.1`
- `media.methodologies.spectral-integrity-provider/0.1`
- `media.methodologies.revision/0.1`
- `media.methodologies.generalized-compute/0.1`


## Dev8 — spectral-integrity lineages, revision lifecycle and compute planning

Dev8 grows the open catalogue from 175 to **180 methodologies** by importing five bounded methods from Audio Spectral Integrity v0.2: complementary alternating-bucket views, bucket-origin phase sensitivity, bounded preference listening views, externally seeded harmonic observations, and the known two-input interleave positive control.  These methods preserve the upstream rule that odd/even bucket views split one captured waveform and are **not source separation**.

`MediaSpectralIntegrityProviders.cls` exposes provider profiles and live applicability.  Harmonic observation remains `UNKNOWN` until an independently supplied f0 hypothesis exists; the positive control remains unavailable until both known control inputs exist.  The Python adapter dynamically loads the upstream v0.2 implementation instead of copying its DSP.

Dev8 also adds `MediaMethodologyRevision.cls`, which consumes detached EvidenceRevisionAudit classifications only to manage candidate/comparison lifecycle.  A later result can mark a candidate `REVISED`, `QUARANTINED` or `REVIEW_REQUIRED`, but no revision can promote derived media into captured observation or assert factual truth.

`MediaGeneralizedComputeBridge.cls` projects the exact media task, implementation profile and source references into Generalized Compute Intentions.  The result is planning evidence only: `mutationAuthority=NONE`, `revalidationRequired=true`, and any prepared handoff still requires authoritative COMPUTE/ALLOCATION/WLU/ROUTER revalidation.

See `spec/AUDIO_SPECTRAL_INTEGRITY_METHODS.md`, `spec/EVIDENCE_REVISION_INTEGRATION.md`, and `spec/GENERALIZED_COMPUTE_PLANNING.md`.

## Dev7 — execution locality without scientific drift

Dev7 rebases the Audio V9 execution integration onto Candidate20 and adds an optional sequence-locality bridge.  FIXED_EXECUTION, MOVE_TO_STORAGE, MOVE_TO_MEMORY, LOOKAHEAD_LOCALITY and the remaining Candidate20 policies are treated as execution strategies, not media methodologies.  The bridge records locality/failover metrics plus reconstruction equivalence and deliberately cannot mint Job-to-Node authority.  See `spec/SEQUENCE_LOCALITY_EXECUTION.md`.

## Dev6 direction

Dev6 extends the plural-experiment model to executable audio restoration/reconstruction providers.  No implementation is preferred by the catalogue, and no candidate waveform is promoted to captured observation.  Shared implementation foundations are recorded explicitly so apparent agreement is not confused with independent corroboration.

The dev5 Audio V9 multipath line is retained and rebased to Candidate18r1.  Dev6 adds spectral subtraction, Wiener filtering, NMF denoising, harmonic/percussive separation and experimental spectral repair as separate executable lineages.

Dev5 grows the open catalogue from 170 to **175 methodologies** by adding five explicit acoustic-multipath techniques from the qualified Audio V9 line. They are not hidden inside generic echo-cancellation or beamforming labels: coherent-path estimation, spectral trajectory tracking, motion-induced coherence, bounded physics compatibility and multipath virtual-microphone reconstruction each keep their own assumptions and failure modes.

The first Audio V9 reference provider delegates to the existing Candidate18r1 native/ooRexx implementations rather than duplicating their DSP. Media Methodologies records execution profiles, applicability, provenance and candidate/measurement authority only. Audio V9 remains the owner of its acoustic calculations.

The real TP00001 qualification uses source file PTS 8435–8445 s. At the previously measured speech-energy onset (8437.8275 s), the sparse path estimator reports seven useful coherent delayed paths at 8.25, 14.375, 20.625, 27.0, 35.5, 41.75 and 48.0 ms. A low-energy control at +6.3 s returns `NOT_APPLICABLE / NO_USEFUL_COHERENT_PATH`. Those are path-support observations only; they do not establish source range, reflector geometry, source identity or transcript content.

The non-amplifying virtual-microphone branch produces a **derived candidate waveform** from the same measured path foundation. It is explicitly marked dependent on the path estimator and therefore cannot be counted as independent corroboration of that estimator.

Applicability is live rather than catalogue-static. `MediaAudioV9ApplicabilityProvider` re-evaluates the current object/evidence state on each discovery: path estimation becomes applicable only when source audio and an explicit onset are present; spectral tracking requires an explicit time range; motion coherence waits for measured trajectory observations; physics compatibility waits for measured spectral trajectories; and virtual-microphone reconstruction remains `UNKNOWN` until coherent path support has actually been measured.

Dev5 also adds an optional Instrumentation Mesh dev7 adapter. Method execution STARTED/COMPLETED/NOT_APPLICABLE/FAILED events can now flow into the replay-safe operational timeline and Wire3D dev29.22 NOC. Those events are operational observations, not media evidence, and cannot promote reconstruction into observation.

See `spec/AUDIO_MULTIPATH_METHODS.md` and `spec/INSTRUMENTATION_EVENTS.md`.

# Prior dev4 video-provider baseline

API family:

- `media.methodologies/0.1`
- `media.methodologies.execution/0.1`
- `media.methodologies.intentions/0.1`
- `media.methodologies.experiment/0.1`
- `media.methodologies.reference-video-provider/0.1`

## Purpose

This package is an open catalogue and experiment fabric for audio/video/media processing techniques. It deliberately does **not** define one preferred algorithm. The catalogue began with the 170-method dev1 baseline and is now extended by explicitly versioned additions; dev2 added distributed work shapes; dev3 added dynamic intentions and plural scientific lineages; dev4 makes the first reconstruction family executable through a non-preferred reference provider.

Experimental methods remain first-class. An experimental method may recover only part of a subject, may fail on some geometry, and may disagree with another method. It must preserve its assumptions, support and uncertainty and must never promote a reconstruction into captured observation.

## Five executable reconstruction lineages

`providers/reference_video_reconstruction.py` supplies one reference implementation for:

- `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION`
- `VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL`
- `VIDEO.RECON.FLOW_WARP_ACCUMULATE`
- `VIDEO.RECON.MOVING_STRIP_MOSAIC`
- `VIDEO.RECON.LATENT_MULTI_FRAME`

The provider is deliberately marked `EXPERIMENTAL_REFERENCE`. It is not the canonical implementation of any methodology. Other implementations can use different tracking, deconvolution, PSF estimation, Bayesian inference, GPU kernels or learned models and remain separate implementation lineages.

Every provider output is a `CANDIDATE` with three materials: an RGBA candidate image, a support map and an uncertainty map. Unsupported pixels stay transparent/zero. The provider result explicitly records `observation_promotion=false`.

The user's leading-edge idea is represented conservatively: the observed leading support boundary is used as a higher-confidence registration constraint and source-supported material is backprojected behind it through time. The specification does **not** assert that a motion-blurred edge is literally an instantaneous sharp sample; real shutter exposure integrates light through time.

## Shared-foundation accounting

Dev4 also records the implementation foundations used by each provider result. This matters because agreement between two methods is not automatically independent corroboration. In the real qualification run, flow-warp accumulation and latent multi-frame reconstruction agree strongly, but both share the same Farneback reference warp and robust supported-median stack. The comparator therefore marks that agreement `DEPENDENT_IMPLEMENTATION_PATH` rather than treating it as independent evidence.

## Real-media qualification

The reference provider was run against the already-qualified FC TP116 left-to-right road-motion event from source `20231012_084716_tp00116.mp4`, SHA-256 `e75ac56fc14d068233a7fd42f2a51a4b324b77450c30bbbe1d08001be7b3d4f9`.

The provider received source-relative 479.3–481.1 s and the FC-derived crop x=900, y=720, width=420, height=360. The five methodologies each returned a derived reconstruction candidate using 14 usable moving-foreground frames. The real sequence contains substantial occlusion by the balcony/rail structure; different methods produce materially different supported reconstructions. The comparison layer keeps that disagreement visible and elects no winner.

A quiet TP116 control at 590–592 s was also run in the same crop. All five methods returned `NOT_APPLICABLE / INSUFFICIENT_MOTION_SUPPORT`, demonstrating fail-closed applicability rather than forced reconstruction.

The real run is a motion/occlusion stress case. It is not claimed to prove that this source is blur-dominated or that any candidate is ground truth.

## Controlled blur qualification

A generated fixture integrates seven object subpositions into each frame to create known horizontal motion blur, then places stationary foreground occluders over the frame. All five methods produce supported derived candidates. The results deliberately differ: some improve edge-energy descriptors, some retain larger supported regions, and some expose occlusion/registration artifacts. Edge energy is recorded only as a descriptor, never as a fidelity or winner score.

## ooRexx execution seam

`src/MediaReferenceVideoProviders.cls` exposes five `MediaImplementationExecutionProfile` objects requiring `MEDIA.VIDEO.DECODE` and `MEDIA.PYTHON.OPENCV`. These profiles can flow through the existing RexxOS / Job-to-Node placement path from dev2/dev3.

`tools/run_reference_video_provider.rex` is the first executable ooRexx-to-provider driver: it reads a provider job, resolves the explicit methodology implementation, invokes the reference provider, and leaves the structured result for experiment assembly/comparison.

## Current fabric boundaries

Memory Fabric still owns sparse/reference working sets and adaptive horizon demand. RexxOS supplies MI identity/incarnation. Job-to-Node owns admission, placement and leases. Media Methodologies owns the semantic methodology/lineage/task/candidate model. The reference provider owns only one implementation family. None of these layers can promote derived reconstruction into original evidence.

## Current reviewed Library heads

- Memory Fabric v0.1-dev10 — SHA-256 `91a05494c86ce7627f7a010af182c167701b5bf1f8ce2d93c99cda9d992644d8`
- RexxOS RTO2 Grid v0.1-dev14 — SHA-256 `693a5e4d696790d10e1c366c77849514918ca558510cbf696189442f464b0e0a`
- Job-to-Node Allocator v0.6-network4 — SHA-256 `f7762988f38cb29f0ef5f7d63859e77c0c19a7069991f353365630b791363240`
- Vision v0.1-dev21 merged snapshot/intention branch — SHA-256 `8401691cccb90c3702159b036d89123bd640eb8e57b60d5d518cdf735525974b`
- Layered Audio v0.22-dev5 — SHA-256 `655d7d07532e99b4b318db02516cd791f00c2c53bd22a461c06aa90887b17792`

These are compatibility/deployment references and are not vendored.

## Qualification

Fresh dev5 qualification used ooRexx 5.3.0 r13196. All **18** main package tests pass, including live Audio V9 applicability rediscovery; all **42** source/test/example/tool/integration-harness Rexx files compile; the provider Python modules compile; JSON schemas validate all 175 methodology/work-shape identities plus the Audio V9 qualification jobs/results; real and controlled Audio V9/provider campaigns execute; and the existing RexxOS / Job-to-Node / Memory Fabric / Layered Audio / Instrumentation integrations remain green. The strict ooRexx standards pass scans all 42 Rexx files with **0 errors and 0 warnings**; the result is recorded in the dev5 qualification material.

See `qualification/reference_provider/tp116_real/QUALIFICATION.md`, `qualification/reference_provider/synthetic_run/QUALIFICATION.md`, and `spec/REFERENCE_VIDEO_RECONSTRUCTION_PROVIDERS.md`.

## dev6 — plural executable audio reconstruction

Dev6 supplies five reference implementations for already-defined audio methodologies.  They are implementations, not preferred answers.  Each candidate declares its implementation foundations and remains derived material.

A controlled fixture deliberately demonstrates both success and failure: spectral subtraction and Wiener filtering improve known-truth SNR; the NMF heuristic does not; the experimental spectral-repair implementation makes its masked-region known-truth error worse.  Failed improvement is retained as qualification evidence rather than hidden.

On real TP00001 audio there is no clean truth.  Candidate-to-source and candidate-to-candidate correlation are descriptive only.  Audio V9 Candidate18r1 provides a separate coherent-multipath lineage and its disagreement with the STFT-family candidates is retained instead of averaged away.
