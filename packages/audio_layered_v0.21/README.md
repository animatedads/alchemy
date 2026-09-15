# Layered Audio ooRexx v0.21

Layered Audio is an ooRexx evidence model for raw/derived audio, processing lineage, independent assessment views, multi-layer transcripts, fragmentation lattices, pitch, speaker embeddings, music fingerprints, ML provenance, spatial hypotheses, cross-recording scene alignment, camera/audio provenance and native FFmpeg DSP/decode providers.

## v0.21 stateful streaming and runtime-owned JSON fallback

v0.21 makes stateful processor sessions real rather than declarative. `AudioForeignPythonProcessingSession~openStream()` now keeps provider state across successive `AudioProcessingBlock` calls for adaptive spectral denoise and echo-persistence processing, and promotes time-scoped dynamic filters to an executable stateful reference processor. The semantic `AudioProcessingStreamSession` owns sequence/EOS/flush/version state while the ForeignPython session owns numerical history such as learned noise floors, delay history and IIR filter `zi`. `AudioProcessingStreamCheckpoint` records only detached summary/provenance; live Python/tensor state is never serialized as evidence.

`AudioFilterRule` and `AudioDynamicFilterPlan` replace the first-generation timestamp-keyed JSON filter maps with explicit sample-domain intervals. A rule can therefore apply deterministically to offline material, a live stream block, or a remote processing block without depending on wall-clock parsing inside Python.

Stateful placement is now explicit. `AudioStreamingProfile~stateTransferMode` distinguishes NONE / CHECKPOINTABLE / PROVIDER_AFFINE. The current ForeignPython stateful reference processors are `PROVIDER_AFFINE`, so `AudioProcessingPlacementRequirements` sets `sessionAffinityRequired`; `AudioProcessingStreamDispatchEnvelope` carries the semantic session/checkpoint/block/material references for queue/managed-compute integration but contains no live runtime handles.

The historical TCP/JSON Runtime Reference fallback is no longer conditionally skipped for lack of a fictitious external JSON package. `json.cls` and `socket.cls` are resolved from the active ooRexx runtime itself, and the fallback regression is part of qualification when Runtime Reference is supplied.

## v0.20 typed processing graphs and expanded research ports

v0.20 turns the v0.19 processing vocabulary into an executable typed DAG. `AudioProcessingPortRef` distinguishes external runtime material from node-output dependencies; `AudioProcessingGraphExecutor` computes a deterministic topological order and passes resident `ForeignTensor` results directly between compatible processors without byte materialisation. Graph canonical text now serializes typed edge semantics rather than default object strings.

The processor sample contract is now explicitly **per input material**. A two-role processor (`A`, `B`) therefore means two independently addressable materials, not one two-channel material. `AudioProcessorSpec~inputContracts` / `contractForRole()` keep input multiplicity separate from channel shape. This is important for independent camera feeds and the McGill A-law fixture whose left/right channels contain unrelated speech.

Five additional research methods are executable references: blind room-reflection profiling, harmonic-product evidence, spectral-tilt measurement, multi-domain coherence fusion, and harmonic/modulation/tilt log-likelihood feed fusion. `AudioRoomReflectionProfile` and `AudioFeatureMapDescriptor` keep the derived acoustic/feature semantics separate from transient tensor storage. Maths v0.5 evidence now also backs generic processor measurements such as spectral tilt and harmonic concentration.

## v0.19 Audio Processing Toolkit

v0.19 adds the second-generation `AudioProcessingToolkit.cls`: provider-neutral processor specifications/configurations, sample and streaming contracts, execution/placement profiles, processing DAGs, semantic shifts/masks/measurements, explicit stream block sessions and a pure/value offload envelope.  The wrapped historical Python project is treated as a research corpus rather than copied structurally.

The first ForeignPython reference provider re-expresses ten representative methods (GCC-PHAT, envelope/cross-ambiguity alignment, adaptive spectral denoise, phase-coherence Wiener, dual MVDR, CLEAN spectral-line suppression, echo persistence, eigen-noise projection and syllabic modulation).  Python-derived arrays remain resident `ForeignTensor` bindings for efficient chaining. ooRexx Maths v0.5 supplies numerical evidence for correlation/alignment measurements while Audio retains the domain claim. See `AUDIO_PROCESSING_TOOLKIT.md`, `RESEARCH_METHOD_CORPUS.md` and `GPU_OFFLOAD.md`.

The McGill `M1F1-Alaw-AFsp.wav` external fixture is qualified as two independent 8 kHz channels: Pearson correlation about `0.006968`, preventing accidental early downmix from being treated as harmless.

## v0.18 ForeignPython collection proxies

Foreign Runtime v0.22.2 adds Rexx-native traversal for resident Python sequence/mapping proxies. Layered Audio no longer requires Python-returned envelopes to be eagerly converted into `.Array`. `ForeignPythonSequenceSupport` accepts ordinary ooRexx arrays or resident `.ForeignPythonObject` sequences through the common `items` and one-based `[]`/`at()` contract, while `pythonAt()` remains available for exact Python indexing. Persistent evidence is explicitly copied into ooRexx values only at the evidence boundary.

The ASR result path and speaker embedding/verification providers use this contract. A regression returns custom Python sequence objects that remain resident and proves one-based Rexx traversal, negative Python indexing, and explicit final Rexxification of the persisted embedding vector.

## Inherited from v0.16: provider-neutral tensor material

v0.16 introduced a narrow generic tensor description and an audio-specific tensor binding; v0.17 preserves that contract:

- `MLTensorDescriptor` records protocol, dtype, shape, byte strides, device type/id/name and readonly state.
- `AudioMLTensorBinding` links one runtime tensor to one `AudioMLMaterialBinding` while retaining the persistent material provenance separately from transient runtime state.

The process-local `ForeignTensor~nativeHandle` is intentionally **not** part of canonical/persistent evidence. It is a runtime capability only.

Qualified local material path:

`AudioMLMaterialSpec -> ForeignBuffer -> Python memoryview/NumPy -> ForeignTensor -> provider-neutral native tensor descriptor`

On Foreign Runtime v0.22.2 the same tensor can be inspected by an independent native consumer using only the v1 tensor descriptor ABI. DLPack remains provider-internal for Python-to-Python handoff.

## Real camera tensor-material qualification

Using the external camera fixture `1000053605.mp4`, the inherited tensor-material path remains qualified:

`MP4/AAC -> native FFmpeg decode -> mono fltp @ 16 kHz -> explicit materialization into ForeignBuffer -> NumPy frombuffer -> ForeignTensor -> native tensor descriptor`

The bounded fixture decode yields 8192 float32 samples. The transition from the Runtime Reference value result (`pcm_planes[1]`) into the managed `ForeignBuffer` is **one explicit copy**. From that ForeignBuffer into NumPy/ForeignTensor/native tensor-descriptor consumers, host storage is shared.

This package does not claim that the entire camera-to-ML pipeline is zero-copy, and it does not claim GPU execution.

## Tensor lifetime rule

Foreign Runtime correctly pins shared storage while Python/native consumers remain live. Tests explicitly close intermediate resident proxies returned by in-place Python/Torch calls before closing the underlying ForeignBuffer. This is part of the runtime ownership contract, not a workaround.

## Runtime Reference boundary

Runtime Reference v0.4 preserves the value-oriented remote boundary used here. v0.20 continues not to smuggle resident `ForeignTensor` objects through a remote/value contract. Existing speaker embedding operations remain provider-neutral value operations. Tensor material is a local runtime binding that can be consumed by compatible local providers/native consumers; a future Runtime Reference object/token contract can expose that selection without violating PURE semantics.

## Camera Behaviour v0.52 interop

Camera Behaviour and Layered Audio remain adjacent semantic owners. Camera owns camera/capture behaviour and visual semantics; Layered Audio owns acoustic recordings, processing, scene alignment, assessment and ML-ready acoustic material.

## Qualification

Qualified against:

- ooRexx 5.3.0 r13196 Internal Test Version
- ooRexx Foreign Runtime v0.22.5
- Runtime Reference v0.4
- ooRexx Maths v0.5
- Camera Behaviour ooRexx v0.52 as adjacent integration context
- FFmpeg 7.1.5 ABI family (`libavformat.so.61`, `libavcodec.so.61`, `libavutil.so.59`, `libswresample.so.5`)
- SpeechBrain 1.1.0 / Torch 2.10.0+cpu / torchaudio 2.10.0+cpu for optional embedded Python qualification

The external camera media is validation input only and is not redistributed.


## v0.17 ASR preparation

The early transcription sample proved the v0.22.1 ForeignTensor/DLPack/Torch/SpeechBrain execution path but also demonstrated language-model-heavy hallucination when low-SNR camera ambience was blindly split into two-second chunks. v0.17 treats segmentation itself as an assessment hypothesis. `AudioASRForeignPythonSession` asks `audio_asr_foreign.speech_regions()` for conservative utterance-sized regions, prepares each region with bounded enhancement, and returns candidate lexical text to ordinary Layered Audio transcript boundaries.

The default SpeechBrain `asr-crdnn-rnnlm-librispeech` model remains a model trained for LibriSpeech-style read speech, not a claim of suitability for every noisy conversational camera recording. The sample therefore emits automatic candidate boundaries and does not invent lexical confidence.
