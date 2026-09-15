# Audio Processing Toolkit v0.21

## Purpose

The toolkit is the second-generation engineering surface for the experimental audio-processing methods collected in `pyaudprocessing.zip`.  It intentionally does **not** choose one enhancer as authoritative.  Different algorithms, parameter sets, channels, source groups and processing branches may coexist as derived Layered Audio material.

The original scripts are treated as a research/method corpus.  Project file discovery, YAML layouts, ad-hoc timelines, implicit NumPy shifts, hidden constants and one-off output naming are not copied into the ooRexx API.

## Core rules

1. Source evidence is immutable. Processing creates derived material or measurements.
2. A shift/mask/measurement is a typed object, not an implicit array operation.
3. Processor semantics are independent of provider/runtime placement.
4. Parameter sets are complete named configurations. Different settings are different trials.
5. Streaming geometry is declared by contract: block size, provider history, look-ahead, external overlap, flush and block parallelism. Stateful reference processors own their history internally; external overlap is not silently duplicated.
6. GPU suitability is a placement requirement/hint, not part of algorithm identity.
7. Multiple branches are normal. There is deliberately no `best()` processor.
8. Numerical agreement is evidence, not domain truth. ooRexx Maths evidence may support an Audio claim without collapsing the two.
9. Process-local `ForeignBuffer` / `ForeignTensor` capabilities never enter persistent/offload envelopes.

## Object vocabulary

`AudioProcessorSpec` describes semantic processor identity, family, input roles, output kinds, per-role sample contracts, streaming profile, execution profile, parameter schema, research provenance and implementation status. Input role count and channel count are deliberately separate: A+B means two materials, not stereo.

`AudioProcessorConfig` binds a complete parameter set to a processor.  Two configurations of GCC-PHAT with different lag windows are separate configurations even though the algorithm is the same.

`AudioProcessingGraph` and `AudioProcessingNode` represent forks/merges and preserve parallel trials. `AudioProcessingPortRef` gives each runtime edge explicit EXTERNAL or NODE-output semantics; `AudioProcessingGraphExecutor` topologically executes the DAG and may pass resident tensors directly between nodes. A graph may retain several enhancement branches over the same source interval.

`AudioProcessingBlock`, `AudioProcessingStreamSession`, `AudioProcessingStreamCheckpoint` and `AudioProcessingStreamBlockResult` make block geometry, persistent state version, EOS and explicit flush lifecycle visible rather than leaving them hidden in a provider loop. `AudioFilterRule` / `AudioDynamicFilterPlan` own time-scoped filter semantics in sample coordinates.

`AudioTimeShift`, `AudioMeasurement`, `AudioMaskDescriptor`, `AudioRoomReflectionProfile`, and `AudioFeatureMapDescriptor` represent semantic outputs. Runtime arrays/tensors are separate transient bindings.

`AudioProcessingPlacementRequirements` exports CPU/GPU/working-set/capability requirements without performing node ranking or allocation. Stateful processors additionally declare NONE / CHECKPOINTABLE / PROVIDER_AFFINE transfer semantics; provider-affine sessions request placement affinity.

`AudioProcessingDispatchEnvelope` is a pure/value envelope suitable for Runtime Reference, queues or managed-compute adapters. `AudioProcessingStreamDispatchEnvelope` is the corresponding per-block/session value envelope. Both contain semantic input/checkpoint references only; live runtime handles are prohibited by construction.

## Processor families

The current normalized families are:

- ALIGNMENT — GCC-PHAT, envelope lag, cross-ambiguity.
- TRANSFORM — adaptive spectral denoise, MVDR, CLEAN spectral-line suppression, eigen-noise projection, dynamic filters.
- MASK — phase-coherence Wiener, echo persistence, multi/five-domain coherence, syllabic modulation.
- MEASUREMENT — room profile, harmonic product, spectral tilt and other numerical evidence.
- SPATIAL — TDOA/geometric candidate scoring and zone likelihood.
- CLASSIFIER — semantic/event classifiers that may consume measurements/material but do not own signal transformation.
- COMPOSITE — explicit orchestration graphs such as zonal scene rendering.

## Reference implementation

`AudioForeignPythonProcessingSession` is the first local reference provider.  It uses Foreign Runtime v0.22.5 `ForeignPython` and consumes native `ForeignBuffer` or resident `ForeignTensor` f32 material.

Reference implementations currently qualified (v0.21 adds stateful execution for adaptive spectral denoise, echo persistence and dynamic filters):

- `alignment.gcc_phat`
- `alignment.envelope_lag`
- `alignment.cross_ambiguity`
- `transform.adaptive_spectral_denoise`
- `mask.phase_coherence_wiener`
- `transform.mvdr.dual`
- `transform.clean_spectral_lines`
- `mask.echo_persistence`
- `transform.eigen_noise_projection`
- `mask.syllabic_modulation`
- `measurement.room_profile`
- `measurement.harmonic_product`
- `measurement.spectral_tilt`
- `mask.coherence.multi_domain`
- `transform.log_likelihood_fusion`
- `transform.dynamic_filters`

Python-produced arrays remain `ForeignTensor` runtime bindings so another Python/tensor processor can consume them without byte materialisation.  Converting a derived tensor to native bytes is an explicit materialisation boundary.

## GPU/offload seam

Processor execution profiles declare `gpuMode` as NONE / OPTIONAL / PREFERRED / REQUIRED, minimum VRAM where known, batchability, working-set hints and capability requirements.  Audio does not rank nodes or reserve GPUs.

A later adapter may translate `AudioProcessingPlacementRequirements` into the authoritative Job-to-Node allocator requirements.  Hard eligibility remains allocator policy; spare capacity/performance cannot override hard security/legal/runtime requirements.

## Maths evidence

`AudioMathsEvidence` creates Maths v0.5 `MathEvidence` for correlation, alignment and generic processor measurements using an explicit binary64/NumPy path.  The evidence records numerical checks and explicitly states that correlation/lag agreement does not itself prove speaker identity, source identity or exact synchronization.


## v0.21 stateful reference sessions

`AudioForeignPythonProcessingSession~openStream()` currently provides real stateful sessions for adaptive spectral denoise, echo persistence and dynamic filters. The semantic ooRexx session tracks block sequence, source geometry, EOS, flush and state version. Provider state is intentionally separate: adaptive denoise carries a learned spectral floor and input history; echo persistence carries bounded delay history; dynamic filters carry active IIR `zi`. `AudioProcessingStreamCheckpoint` exposes detached summary/provenance only.

`AudioFilterRule` uses half-open sample intervals `[startSample,endSample)` (or open-ended `endSample=-1`). `AudioDynamicFilterPlan` chooses the active rules for each logical block and caps filters per block. This replaces wall-clock string parsing inside signal code and makes offline/streaming/remote execution share one rule meaning.
