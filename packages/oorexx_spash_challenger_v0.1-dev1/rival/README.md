# SPASH Rival — adaptive spectral experiment engine v0.1

**Independent competitor to Claude's audio work**. Architecture and challenge: Tom Dyer. Implemented ChatGPT GPT-6, 31 October 2026. An isolated, clean-sheet ooRexx package; does not fork Audio V9 DSP or Claude's output.

## Executed, not proposed

Five strategy profiles x five spectral-run window lengths x four thresholds = **100 deterministic strategies**. The ooRexx engine parses actual measured Audio V9 Candidate21 `audio.v9.multipath.spectral-track/1` observations, computes bounded cross-method coherence/stability/coverage objectives, retains top-ranked methods, and emits intervals with source lineage and **candidate-only** status. A strategy is not an audio recognizer. It does not label speech or classify sources from three-band features alone. This is an early, unsupervised ranking baseline, NOT noise-reduction parameter recovery or a complete speech-enhancement algorithm.

All spectral measurements were done by existing Audio V9 native providers. No Python DSP, NumPy, ffmpeg processing, new FFT, audio mixing or decoded PCM is present in the Rival implementation. Retain original media as immutable Storage Fabric material refs; a separate owner-run reconstruction will render selected views.

### Actual native test

```sh
REXX_BIN=/path/to/rexx sh run_tests.sh /private/FD_TP7/measured_spectral_paths.tsv /private/SPASH_RECOVERED_VISUAL_EVENTS_362.tsv
REXX_BIN=/path/to/rexx sh run_tests.sh /private/FC_TP28/measured_spectral_paths.tsv /private/SPASH_RECOVERED_VISUAL_EVENTS_362.tsv
```

The bundled StorageFabric stub exists **only** for source-admission and metadata-contract unit tests; never put that stub on a deployed `REXX_PATH`. In production use the actual `packages/oorexx_storage_fabric/src/StorageFabric.cls` implementation, a checked original `StorageRef`, and an authoritative `StorageCatalogue`. Storage layer writes in this version are catalogue **registrations**, not a fully checkpointed/replicated storage commit. No private input or original SHA is committed here.

### Running in production against already measured spectral tracks

```sh
REXX_PATH="/path/to/real/storagefabric/src:$PWD/src" rexx rival_scan.rex /private/native_tracks.tsv ORIGINAL_STORAGE_REF ORIGINAL_SHA256 /private/recovered_video_events.tsv
```

**Do not** apply this to raw waveforms as a substitute for the earlier required three-stage original -> existing acoustic model -> reconstructed SPASH likeness pipeline. This package currently searches measured spectral *path features* and prepares candidate windows, not recovered audio.

## The five Strategy Layer profiles

`PATH_COHERENCE`, `SPECTRAL_STABILITY`, `LOW_ENERGY_RETAIN`, `MULTIBAND_BALANCE`, `MOTION_RESIDUAL`. Strategy selection uses 2, 4, 8, 16, 32-frame continuity windows and gate thresholds .35, .45, .55, .65. Each profile weights existing Audio V9 coherence, spectral stability, path strength and band balance differently. Weights are experimental, not calibrated likelihoods. The current code declares its local strategy registry; integrating with any separately owned Programme Strategy Layer service requires an explicit owner adapter (none has been verified at runtime).

## Explicit siren / klaxon false-positive suppression

When independent *measured* narrowband features are supplied, persistence+sweep signals a **SIREN_LIKE_VETO** and persistence+two-tone switching a **KLAXON_LIKE_VETO**. Vetoed blocks cannot be selected, regardless of their path coherence or apparent likelihood. When those features are absent in the three-band Audio V9 TSV, result is **UNTESTED_CONFOUND**, not a false 'no siren' finding. All selected intervals are `ACOUSTIC_CANDIDATE_ONLY_NOT_VERIFIED_VOICE`, never asserted human speech. Real siren-veto performance is **not yet measured**; synthetic controls prove fail-closed rule mechanics, not effectiveness against recorded sirens.

## Layered Audio / Storage Fabric

`SpashRivalLayers~register(catalogue,layerRef,originalRef,role,methodId,byteCount)` uses the existing `StorageObject`, `StorageEA` and `StorageCatalogue` APIs; layers `ORIGINAL`, `MEASURED_SPECTRAL`, `STRATEGY_VIEW`, `MODEL_VIRTUAL`, `LISTENING_DERIVATIVE` retain original StorageRef lineage, method and authority. This does not duplicate binary audio and will refuse overwriting an existing immutable layer. Resident Memory Fabric block refs and job-to-data scheduling are upstream owner responsibilities.

## Video-event anchors

`SpashRivalEventLedger` accepts the previously recovered 362-event FC/FD table, retains source event IDs and PTS-relative temporal authority, but **does not invent an audio/video clock**. The event stays context-only unless a verified audio/video clock model with uncertainty is separately supplied. Its role is *experimental stratification / held-out event windows*, not named sound recognition. The later 426-event library revision can be supplied with the same schema.

## 10 MU / 20+ MI capacity

`SpashRivalMUSharder` plans ten strategy slots, 10 of the 100 configurations per MU. These are **PLANNED_NOT_DISPATCHED** work intents and no network work is claimed. Separate Queue/Job-to-Node controls must actually admit workers and make Memory Fabric data resident. GPU budget is not required to execute this current native metric search; it is an optional resource for future owner-provided reconstruction strategies, not an excuse for blocking the baseline.

## Release gates and limitations

- Need held-out POI1/V7 positives and stratified negative siren/klaxon controls processed by the existing native providers before claiming speech accuracy or noise suppression improvements.
- Need owner-approved live Strategy Layer adapter (current profiles local to Rival), actual durable Storage Fabric checkpoint and native reconstruction of selected intervals.
- Need exact FC↔FD source clock mapping to use the recovered video events for observed acoustic coincidences.
- Need full four-model-position Audio V9/Physics World rendering and independent tests; 10-MU plan is not a 10-MU run.
- Human user reviewed all 463 Tier A V7 clips as speech-present; that is a private positive-review set, not a new measured label for untreated TP7/TP28 tracks.
- No source PCM, POI1, personal recording data, private source hash, decoded audio, GPU job or unapproved external processor is published.