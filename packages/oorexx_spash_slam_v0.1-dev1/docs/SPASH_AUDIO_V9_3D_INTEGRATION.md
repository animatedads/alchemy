# SPASH SLAM → Audio V9 / Physics World 3D acoustic processing — integration contract v0.1

**Architecture:** Tom Dyer. **This integration proposal and qualification boundary:** ChatGPT GPT-6, 30 October 2026.

## Purpose

The private dual-feed V7 recording contains faint conversation submerged under broad background sound. SPASH identified 912 candidate listening intervals and the user reviewed **all 463 Tier A clips**, reporting human speech in **463/463**. That is a user-reported positive rate **within the reviewed Tier A set**, not a measured speech recall rate and not confirmation of distinct sources or physical location.

The new 3D acoustic processing pipeline should consume **source-referenced candidate intervals and spectral-path hypotheses**, not a permanently flattened/stereo-derived waveform as its only evidence. SPASH contributes *where to experiment* and *which observations may belong to a continuous path*. Audio V9, Media Methodologies and Physics World remain owners of DSP, path estimation, motion/coherence and propagation physics.

## Required input authority: original two acoustic feed observations

- Use the original independently recorded FC/FD streams when available, with immutable hashes, codec information, native decoded sample positions, and explicit observed clock/alignment evidence.
- Treat V7 as a *derived listening product*. Its channel 1 and 2 may contain distinguishable material, but their recorded stereo layout alone does not prove two independent microphone positions or the synchronization of the underlying original sources.
- V7's third processed channel was silent during the prior whole-file scan; no new spatial evidence comes from it. Do not silently replace lost source feeds or invent independent channels.
- The upstream packet/granule boundary cannot substitute for post-resample sample geometry. Reuse V9's exact decoded-sample and normalization-sidecar rules.
- Known microphone/camera poses, acoustic media, reflector geometry, clock models and uncertainties must be explicit and externally sourced. Absent these, report geometry **UNKNOWN**, not a solved 3D position.

## Minimal proposed request: `spash.spatial.candidate/0.1`

This is a **schema proposal**, not a deployed API. One candidate object should contain:

```json
{
  "schema": "spash.spatial.candidate/0.1",
  "candidateId": "SPASH-CANDIDATE-IDENTITY",
  "recordingLineage": [
    {
      "feedId": "FC",
      "originalSha256": "REQUIRED_SOURCE_HASH",
      "sampleRateHz": "EXACT_RATE",
      "startSample": "EXACT_INTEGER",
      "sampleCount": "EXACT_INTEGER",
      "clockModelId": "EXPLICIT_OR_UNKNOWN",
      "channelAuthority": "OBSERVED"
    }
  ],
  "features": {
    "spectralObservationRefs": [],
    "continuationPathRefs": [],
    "similarityMethodId": "EXPLICIT",
    "sharedMethodFoundationId": "EXPLICIT"
  },
  "hypothesisPolicy": {
    "sourceCount": "UNRESOLVED",
    "geometry": "EXTERNALLY_PINNED_OR_UNKNOWN",
    "virtualMicrophones": "MODEL_PREDICTIONS_ONLY",
    "allowSegmentSplit": true,
    "allowHypothesisBranch": true,
    "noAutomaticDeletion": true
  },
  "reviewEvidence": {
    "voicePresence": "USER_REPORTED_OR_UNREVIEWED",
    "reviewReceiptRef": "OPTIONAL_PRIVATE_HASH_BOUND_REF"
  }
}
```

The uppercase placeholders are intentionally unresolved: callers must supply real values or report absence. The object must not contain private PCM, full transcript, or personal identifying information in routine inter-node messages. Heavy audio and FFT/STFT state remain destination-local, per Physics World's `f11-acoustic-context` pattern.

## Experimental stages

1. **Acquire and verify.** Reopen original feed windows with adequate margins around SPASH Tier A starts/ends, pin both feed hashes and exact sample indices, and register any source clock uncertainty. Preserve source-native channels.
2. **Propose multiple explanatory paths.** Test direct/reflective acoustic paths and competing 3D source/reflector configurations. Do not assert a single geometry merely because it scores best.
3. **Four virtual microphone viewpoints.** For each *candidate geometry*, predict delays, spectral transfer and motion-induced changes at four hypothetical positions. These four predictions are **not four independent observations**.
4. **Measure observed-to-predicted residuals.** Use independently observed FC/FD delay, Doppler/time warp, coherent spectral trajectory, transfer stability and waveform overlap where source data supports them. Record residuals on held-out intervals, not only the training segment. No circular confirmation between one method and a derivative using the same foundation.
5. **Split/continue/revise.** Permit a stable background path and intermittent speech-like path to co-exist. Segment boundaries may branch or rejoin only when the observed evidence warrants it. Keep alternate hypotheses and negative trials.
6. **Render evidence and listening separately.** Render per-path **candidate** listening clips from source-native data with exact sample/hop provenance, preserving unaltered material. Allow enhanced audibility without pretending amplification or simulation restored evidence not recorded.
7. **Learn from review.** User speech-presence review helps prioritize later candidate search. It cannot alter the original spectral likeness score or establish speaker/source identity.

## Measurement and qualification gates

- **Identity:** source hashes, method foundations, clock evidence and physical/virtual microphone distinction survive round-trip serialization.
- **Geometry withheld:** no three-dimensional location is asserted when poses/independent observations are unavailable.
- **Held-out validity:** compare candidate motion/echo path predictions to source samples not used to fit the hypothesis; include competing paths and negative controls.
- **Voice protection:** ambiguous low-energy possible speech must not be hard-muted because another path appears background-like.
- **Dual-feed benefit:** compare FC-only, FD-only, simple fusion, path-specific fusion and physics-model predictions on the *same* held-out windows with source-timed listening and objective residuals. No single uncalibrated metric is a truth certificate.
- **Human review:** keep the known 463 user-positive Tier A examples as a private *positive* set. Add Tier B/C and omitted intervals as negative/false-negative challenge sets before reporting precision beyond Tier A or any recall estimate.
- **Runtime:** preserve ooRexx 5.3.0 r13196 ownership and existing Foreign Runtime/Audio V9 provider contracts. No stealth replacement by Python as production DSP.
- **Delivery:** modified audio/video source material stays private; Git may contain code, schemas, tests and aggregate counts but not individual recording hashes, clip indexes, transcriptions or the audio itself.

## Existing programme foundations

- `packages/audio_v9_voice_recovery_v0.1-dev16`: exact normalized audio geometry, spatial census, acoustic source families, ENVELOPE/DIRECT/REFINED delay hypotheses, reconstruction plans and separation of measurement from listening.
- `packages/oorexx_media_methodologies_v0.1-dev8/spec/AUDIO_MULTIPATH_METHODS.md`: coherent-path estimation, spectral tracking, motion coherence, physics compatibility and virtual-microphone reconstruction; explicitly no independent corroboration from derived paths.
- `packages/oorexx_physics_world/CLUSTER_ACOUSTIC_WORKFLOW.md`: destination-local PCM/geometry and full-trajectory candidate work units with compact `physics.f11.candidate-summary/2` results.
- `packages/oorexx_spash_slam_v0.1-dev1`: measured likeness families, source/method-scoped path hypotheses, sample-band plans, explicit virtual microphone model-only predictions and user feedback receipts.

## Ownership and implementation status

This document is a **cross-lane architectural handoff**. No Audio V9, Physics World, microphone geometry, recovered speech, 3D scene, cross-feed clock or deployment was changed by publishing it. A next implementation needs an approved source/measurement adapter and deterministic real+synthetic source-geometry fixtures with withheld-path scoring.
