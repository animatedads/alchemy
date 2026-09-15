# Layered Audio v0.21

- Makes stateful streaming execution real for `transform.adaptive_spectral_denoise` and `mask.echo_persistence`; numerical noise-floor/delay history persists across `AudioProcessingBlock` boundaries in the ForeignPython provider.
- Promotes `transform.dynamic_filters` to an executable stateful reference processor and replaces timestamp-keyed Python filter maps with `AudioFilterRule` / `AudioDynamicFilterPlan` sample-domain objects.
- Adds `AudioProcessingStreamCheckpoint` and `AudioProcessingStreamBlockResult`; semantic stream sequence/EOS/flush/version state remains ooRexx-owned while provider numerical state remains runtime-owned.
- Adds NONE / CHECKPOINTABLE / PROVIDER_AFFINE state-transfer semantics. Current local ForeignPython stateful processors are provider-affine and expose `sessionAffinityRequired` through placement requirements.
- Adds value-only `AudioProcessingStreamDispatchEnvelope` for queue/managed-compute adapters; it carries semantic session/checkpoint/block/material references and never serializes `ForeignBuffer`, `ForeignTensor`, Python proxies or filter state arrays.
- Tightens stateful block semantics: stateful reference processors own their history internally and therefore consume non-overlapped logical input blocks; stateless block processors may still request external overlap through their streaming profile.
- Fixes qualification of the TCP/JSON Runtime Reference fallback: `json.cls` and `socket.cls` are resolved from the active ooRexx runtime instead of being treated as an external dependency. The fallback test now runs under Runtime Reference v0.4.
- Requalifies the full historical + processing suite against ooRexx 5.3.0 r13196, Foreign Runtime v0.22.5, Runtime Reference v0.4 and Maths v0.5.

# Layered Audio v0.20

- Adds typed runtime graph edges with `AudioProcessingPortRef`, deterministic graph dependency ordering, and `AudioProcessingGraphExecutor`.
- Preserves resident `ForeignTensor` outputs across graph edges; materialization to bytes remains explicit.
- Separates processor input multiplicity from per-material channel shape through per-role input contracts; two input roles no longer imply a two-channel material.
- Promotes five more researched methods to executable ForeignPython references: room-reflection profiling, harmonic-product evidence, spectral tilt, multi-domain coherence fusion, and harmonic/modulation/tilt log-likelihood fusion.
- Adds `AudioRoomReflectionProfile` and `AudioFeatureMapDescriptor` semantic objects.
- Extends `AudioMathsEvidence` with generic numerical measurement evidence while keeping Audio-domain claims separate.
- Canonical graph serialization now includes typed edge semantics, suitable for stable evidence/digest use.
- Requalifies the full historical suite against ooRexx 5.3.0 r13196, Foreign Runtime v0.22.5, Runtime Reference v0.4 and Maths v0.5.

# Layered Audio v0.19

- Adds `AudioProcessingToolkit.cls`, the second-generation processor/config/graph/streaming/placement object model.
- Treats the user-supplied historical Python audio project as a method corpus rather than translating script/project plumbing into ooRexx.
- Catalogues 18 normalized processor families/operations; 10 have executable ForeignPython reference implementations in v0.19.
- Adds explicit `AudioTimeShift`, `AudioMeasurement`, `AudioMaskDescriptor`, processing graph, block/session and value-only dispatch envelope semantics.
- Adds `AudioMathsEvidence.cls` using ooRexx Maths v0.5 for binary64 correlation/alignment numerical evidence without escalating numerical agreement into Audio-domain truth.
- Adds `AudioForeignPythonProcessing.cls` and `adapters/audio_processing_foreign.py`; native `ForeignBuffer` inputs cross to Python without a byte copy and Python-produced arrays remain `ForeignTensor` bindings for zero-copy provider chaining.
- Adds CPU/GPU execution profiles and `AudioProcessingPlacementRequirements`; Audio exports placement requirements but does not absorb Job-to-Node allocation authority.
- Qualifies McGill `M1F1-Alaw-AFsp.wav` as a channel-independence regression (8 kHz stereo A-law, cross-channel Pearson r about 0.006968).
- Advances the qualification baseline to Foreign Runtime v0.22.5, Runtime Reference v0.4 and Maths v0.5 from `oorexxapis(20260901-115634).zip`.

# Layered Audio ooRexx v0.18

- Takes Foreign Runtime v0.22.2 as the current runtime baseline.
- Replaces stale `.Array`-only assumptions for Python-returned sequences with the v0.22.2 resident collection-proxy contract.
- Adds `ForeignPythonSequenceSupport` for common ooRexx Array / resident Python sequence traversal.
- ASR `transcribe_batch` results now accept resident Python list/tuple-like proxies.
- Speaker embedding/verification envelopes now accept resident Python sequences; embedding vectors are explicitly copied to ooRexx Arrays only when persisted as Runtime Reference evidence.
- Adds a deterministic custom Python sequence regression covering `items`, one-based `[]`/`at()`, exact `pythonAt(-1)`, and explicit Rexxification at the evidence boundary.
- Preserves and requalifies all v0.17 ASR preparation, native FFmpeg, tensor, scene, transcript, pitch, speaker and Runtime Reference behavior.

- Requalifies the native FFmpeg, ForeignPython and tensor paths against ooRexx Foreign Runtime v0.22.2.
- Adds `AudioASRForeignPythonSession` plus `adapters/audio_asr_foreign.py` for utterance-sized, energy-gated ASR preparation.
- Replaces blind fixed 2-second ASR chopping with adaptive frame-RMS speech-region hypotheses, padding, hangover, merging and bounded maximum region duration.
- Replaces whole-recording peak normalisation with per-region DC removal, 80 Hz high-pass, bounded RMS gain (max +12 dB), and peak limiting.
- Adds a Rexx-facing transcript sample v2 which loads the SpeechBrain model once, reuses it across files, prints per-region transcripts with source-time boundaries, and records each result as a transcript boundary.
- Fails closed if decoded camera PCM is not mono 16 kHz float32 rather than reinterpreting arbitrary sample formats as `<f4`.
- Adds deterministic ASR-preparation regression.
- Does not claim lexical accuracy from the LibriSpeech model on noisy camera speech; generated ASR remains candidate evidence requiring review.

# Changelog

## v0.17

- Requalifies Layered Audio against ooRexx Foreign Runtime v0.22.2.
- Adds narrow provider-neutral `MLTensorDescriptor` metadata: protocol, dtype, shape, byte strides, device and readonly state.
- Adds `AudioMLTensorBinding`, linking runtime tensor material to persistent `AudioMLMaterialSpec`/`AudioMLMaterialBinding` provenance.
- Keeps process-local tensor handles transient and out of canonical/persisted evidence.
- Qualifies ForeignBuffer -> NumPy -> ForeignTensor -> independent native tensor-descriptor consumption using the Foreign Runtime v0.22.2-compatible native tensor ABI.
- Qualifies NumPy -> Torch DLPack shared-host-storage handoff with explicit resident-proxy lifetime cleanup.
- Adds real camera material regression: AAC/MP4 native decode -> 8192 mono 16 kHz float32 samples -> managed material buffer -> ForeignTensor -> native descriptor.
- Documents the one explicit copy from Runtime Reference value-returned PCM into the managed material ForeignBuffer; no false whole-pipeline zero-copy claim.
- Preserves all v0.15 camera, FFmpeg, scene, transcript, pitch, speaker, music and Runtime Reference semantics.

## v0.15

- Adds Camera Behaviour v0.52 provenance interop without semantic ownership collapse.
- Adds native FFmpeg audio decode operation `audio.media.audio.decode/1` through Runtime Reference + Foreign Runtime.
- Qualifies bounded AAC decode from the supplied camera fixture.