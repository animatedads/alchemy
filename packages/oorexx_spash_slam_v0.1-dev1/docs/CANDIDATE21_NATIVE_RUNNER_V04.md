# Candidate21 native source runner — SPASH v0.4

Architecture: Tom Dyer. Source and qualification: ChatGPT GPT-6, 31 October 2026.

## Files delivered here

- `tools/spash_candidate21_plan.rex`: ooRexx adapter calling the **existing** `AudioV9VirtualMicPlanWriter` from `AudioV9Multipath.cls`; refuses an empty measured-path plan.
- `tools/run_spash_candidate21_native.sh`: source-preserving native Audio V9 processing pipeline from original audio to measured spectral-path tracks to virtual-microphone plan to a non-amplified and an optional +32 dB-requested listening reconstruction.
- `patches/audio_v9_candidate21_csvstream_virtual_mic.patch`: **proposed owner patch**, identical in content to the earlier Candidate15 TSV interoperability fix; applies only to a disposable owner-source copy pending Audio V9 owner acceptance.
- `tests/test_candidate21_native_runner.sh`: seven deliberately invalid command-line/admission cases.

This code is **not** a second DSP implementation. It requires the native Audio V9 Candidate21 binaries `av9_multipath_spectral_track` and `av9_virtual_mic_dynamic`, and an ooRexx 5.3.0 r13196 environment.

## Usage

First apply the reviewed TSV patch to a **disposable local copy** of the original Candidate21 owner package and build through its existing `tools/build_audio_v9_acoustics.sh`. Do not overwrite the owner source or bypass its tests.

```sh
sh tools/run_spash_candidate21_native.sh \
  /PRIVATE/original.ogg FD 173 0 \
  /PATH/TO/PATCHED/audio_v9_migratable_dev20_candidate21 \
  /PATH/TO/rexx /PRIVATE/output/fd_trial
```

Parameters: source, physical-feed identity (`FD` or `FC`), *source-relative* start seconds, channel index (0/1/2), owner package directory, ooRexx binary, and a new output directory. It decodes a 15-second context to 8 kHz float32 with ffmpeg, analyzes a 10-second interior region using the existing Audio V9 native spectral provider, writes a TSV plan with ooRexx, runs non-amplified and +32 dB-requested conservative virtual-mic reconstructions through the existing C provider, and writes checksummed WAV listening derivatives and private source SHA receipt.

The output directory must not exist. The runner refuses missing source files, missing native providers, invalid feed/channel arguments, missing ooRexx and a failed/empty measured-path plan. Test with:

```sh
sh tests/test_candidate21_native_runner.sh
```

## Observed private real-audio qualification

An earlier locally run comparison with original user-supplied recordings, with the Candidate21 interoperability patch applied only in the disposable runtime copy, produced:

| Source | Measured spectral trajectory rows | Admitted coherent-path plan rows | Native output |
|---|---:|---:|---|
| FD TP7 | 923 | 217 | 80,000 float32 samples × two derived branches |
| FC TP28 | 765 | 85 | 80,000 float32 samples × two derived branches |

A silent synthetic-source control was NOT_APPLICABLE. Original recordings and `poi1.ogg` were not modified. The private source, WAV clips, measured event rows and their source hashes are deliberately absent from GitHub.

## Nonclaims and mandatory next gate

This test covers stages 1 and 2 of the user's ordering: **original physical feed -> native measured spectral paths -> reconstructed candidate**. It has not exercised all four independent *model-position* alternatives, proved camera clock synchronization, localized a 3D source, matched reconstructed results to unchanged POI1 or run a whole-corpus SPASH search. A derived virtual microphone is not another physical microphone.

For the next live experiment, first establish FC/FD channel clock evidence and original-source lineages, load Physics World F11/F12 geometry and its actual acoustic evaluator, run four model-only viewpoints (predicted source, street, stairwell, other flat), preserve separate derivative identities, and **only then** compare reconstructed candidate views to POI1 and pre-enhanced V7.

## Why a patch is bundled

The unmodified Candidate21 package retains two independent TSV interoperability faults already reported against Candidate15:

1. The old writer attempts a non-existent `CSVStream~separator=` and `lineout(array)`; it must use `AudioV9TsvWriter`.
2. The native C reader must accept CSVStream-style quoted TSV scalar fields.

The patch does not give SPASH ownership of the Audio V9 package. The Audio V9 owner must accept, test and merge it separately. This patch was tested in a disposable copy. The GitHub runner and new tests are newly committed; **the exact latest PR checkout must be independently qualified**. Do not claim those tests have already run on the GitHub commit.

**No private audio, exact source hashes, listening clips or user-derived timestamps are in this source tree.**
