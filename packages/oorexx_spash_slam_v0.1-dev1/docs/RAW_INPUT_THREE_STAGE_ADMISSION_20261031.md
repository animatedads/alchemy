# SPASH native 3-stage reconstruction gate — correction (31 October 2026)

Architecture and processing order: Tom Dyer. This corrective contract records the user's direction after a mistaken raw-waveform matching attempt.

## Non-negotiable processing order

1. **Original FC/FD channels into the existing ooRexx model.** Preserve raw-channel and codec provenance, source hash, original sample-time geometry, clock and measurement uncertainty. Use the existing F11/F12 physics and Audio V9 measurement contracts; do not flatten the two physical feeds, assume clocks agree, or replace the ooRexx processing engine with an ad hoc standalone Python classifier.
2. **Evaluate multiple virtual microphone positions and acoustic propagation hypotheses.** Use the existing Physics World `AcousticMicrophone`, the F11/F12 acoustic model, Audio V9 coherent path estimators, and `AUDIO.RECON.MULTIPATH_VIRTUAL_MIC` as applicable. Retain each virtual microphone's candidate position, model revision, estimated delay / spectral-transfer trajectories, evidence lineage, shared method foundation, and the original source samples from which it was derived. Model-only positions are not independently observed microphones. Some paths may be `NOT_APPLICABLE`; do not manufacture recovered audio.
3. **Only reconstructed candidate views go to SPASH likeness search.** Apply source-hash-bound, source-window-bound candidate comparison against `poi1.ogg`, earlier short recorded captures and the *pre-assembled* `enhanced_dual_feed_v7.ogg` positive reference. Return matches with precise locations in the original FC/FD file plus the reconstruction method, virtual microphone hypothesis, and source lineage. Multiple methods from the same recording are not independent corroboration.

## Crucial correction

Earlier success against V7 was scored on **pre-assembled / enhanced V7 audio**. It cannot be replicated by taking unprocessed `tp00007`/other raw original samples directly to an acoustic-pattern matcher, because low-level conversation is masked by noise. The user's observation is that such a bypass should have effectively zero useful pickup before steps 1 and 2.

The previously computed `~0.51` raw TP7/POI1 likeness from the bypass is **NON-QUALIFYING DIAGNOSTIC**: it neither fails nor validates the physical model, does not establish absence of a sound, and cannot be compared quantitatively with scores from reconstructed V7 or Audio V9 candidates without feature and score calibration.

Audio V9 can still compute path observations on raw channels to drive stages 1–2; these are intermediate measurements, **not final SPASH matches**. The native run that counted spectral trajectory candidates (POI1 335 rows/72 tracks and two TP7 windows 1292 rows/93 tracks) is at this intermediate measurement stage; those counts are not recovered speech events, source counts or successful point-of-interest detections.

## Qualification plan and fail-closed admission

An accepted SPASH result must carry stage-1 ingested-channel evidence, stage-2 virtual-microphone reconstruction evidence, stage-3 comparison method/version, full source/method/clock provenance, and a status distinguishing original observation, model-predicted path, source-based reconstructed waveform and bounded listening enhancement.

If stage-1 geometry, stage-2 path qualification or reconstruction is absent, return `NOT_RECONSTRUCTED` or `INCOMPARABLE`, not a low match score or an implicit negative finding. The high-recall review of 463/463 Tier A candidates applies to the **preprocessed V7** library only and cannot be transferred to untreated raw recordings.

Qualify initially on the known audio window around 02:58 on TP7, the 5.14 s POI1 reference, and existing captured short examples. Compare stage-1/2 model variants to the V7 pre-assembled positive on held-out intervals. Then expand to TP7/TP8 and FC TP28–33, without turning missing video events into negative acoustic evidence.

## Implementation status

The existing model and virtual microphone methods are located, and earlier native spectral-trajectory measurement was run. **A complete stage-1→stage-2→stage-3 raw-FC/FD reconstruction/search run has NOT been qualified in this correction.** The former direct raw similarity route is explicitly invalid for claim of POI1 absence. This document changes scientific admission criteria; it does not claim an already-built matching integration, independent room geometry validation, additional source channels, human-speech transcription, or production deployment.
