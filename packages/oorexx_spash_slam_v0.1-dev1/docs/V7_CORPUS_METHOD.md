# SPASH SLAM — V7 whole-recording spectral search and listening-review contract

**Architecture and naming:** Tom Dyer. **Generic experimental reference code, tests and documentation:** ChatGPT GPT-6, 30 October 2026.

## What was delivered outside GitHub

A privately supplied dual-feed V7 Ogg recording was processed across its full 8h 39m duration. The original listening-delivery archive contains 912 source-referenced candidate clips (463 A / 242 B / 207 C), a full 30-second timeline, an hourly summary, an offline browser and original-source/clip integrity hashes. Clips preserve the two useful source channels as a stereo listening derivative. The third channel was measured as silent during the original pass. The known-positive 02:58 point was retained explicitly.

**The original recording, derived clips, the private indexes, their source digests, private transcript/review receipts, and the 157 MB ZIP are NOT published to GitHub.** They remain under the user's private conversation file delivery. The Git repository contains only generic code, nonidentifying methodology and synthetic test fixtures.

The 912 clips represent a **high-recall candidate inventory**, not 912 demonstrated speech events. The scan retained approximately 6h 21m of potentially relevant audio, especially long regions where broadband noise overwhelms conventional speech-detection confidence. Tier A/B/C are uncalibrated spectral ranking tiers, not probabilities.

## Method from the original listening delivery (documentary record)

- Original source: Vorbis Ogg, 22,050 Hz, three channels; original file kept immutable.
- Audio analysis: each of channels 1 and 2 independently resampled to 8 kHz for measurement; source channel 3 was silent in a separate complete check.
- Windows: 0.5 seconds (4,000 samples), Hann 512-point spectral frames with approximately 256-sample spacing. Six power bands: 30–120, 120–300, 300–600, 600–1200, 1200–2400 and 2400–3900 Hz.
- Evidence: relative energy over 300–3900 Hz, local 20th-percentile noise baseline over 150 seconds, spectral modulation, and a **weak** conventional voice-activity vote in channel 1. Broad VAD alone was too permissive in noisy early material, and did not control admission.
- The higher channel score was used; correlated channels were not counted as independent evidence. Five-bin smoothing, threshold 0.30, brief-gap closure and short candidate windows provided inclusive retrieval.
- Long candidate runs were split at weak points into listening intervals of roughly 20–45 seconds; boundaries were intentionally not asserted to be words, utterances or speaker changes.
- Clips were rendered from the **original** source audio rather than analysis-downsampled PCM, first two channels retained separately, Ogg Opus derivatives. Sample-accurate time mapping and decoder/encoder rounding differences must be accounted for.
- The full candidate index includes source start/end, channel scores, tier, ranking metadata, duration and SHA-256. Silent or excluded 30-second regions were separately indexed for false-negative investigation.

The exact ephemeral generator of the historical archive is not in the Git working tree; do **not** claim that any newly implemented scanner automatically regenerates the same 912 decisions.

## Versioned public reference code (NEW)

The following code is a general-purpose, inspectable starting point for repeats and controlled experiments. It is **not** the historical run's byte-identical implementation.

```bash
python3 tools/spash_v7_scan.py /private/input.ogg --output-dir /private/v7_scan --threshold 0.30 --reference-seconds 178
```

Requires Python/NumPy and ffmpeg/ffprobe. The reference streams the first two source channels in 0.5-second increments, computes six spectral-band measurements, an adaptive activity baseline, and spectral modulation. It outputs a source-hashed candidate **plan** and full half-second timeline. It does not output source audio, recognise words, count speakers, or assert that the same physical source produced two paths. The numerical formula and treatment of the reference anchor are explicit. It does not replicate every historical heuristic, especially the channel-1 weak WebRTC VAD contribution; thus scores/segments and counts can legitimately differ.

Validate a private historical library offline without exposing its audio:

```bash
python3 tools/spash_v7_validate.py /private/SPASH_V7_complete_912_clip_library.zip --source /private/enhanced_dual_feed_v7.ogg
```

The validator checks the manifest schema, source SHA-256 when supplied, candidate count, chronological source spans, allowed review authority, clip file/size/SHA-256, and archive path safety. This is **delivery-integrity qualification**, not a claim that any interval actually contains human speech.

```bash
sh ./run_python_tests.sh
```

Synthetic tests exercise query-by-example and partial replay, review receipts, V7 integrity refusal and streaming scan. Never upload private audio as part of a code-review fixture.

## Human validation received

The user reported that the first three manually reviewed sample-search matches contained human speech, and subsequently reported **100% valid verbals among hour-4 clips listened to so far**. The number reviewed in that hour was not supplied; the report is therefore a provisional **subset-specific observation**, not a claim of 100% precision across all 912 candidates or an estimate of recall. Reciprocal/overlapping sample matches may be dependent. Human speech presence does not establish words, speaker identity, acoustic-source identity, location, intent, or provenance of the recording.

Use `tools/spash_review_feedback.py` to bind an external human review of a published search-report JSON to canonical report/match hashes; never rewrite algorithm scores to fit subjective review. The original review receipts stay private. A V7 browser review-export adapter for large, interval-indexed clip libraries is still a separate integration task.

## Boundaries and open work

1. Determine false-negative rate by inspecting below-threshold portions of the timeline, not just candidate clips.
2. Conduct a blinded human assessment with explicit reviewed counts, independent clips and overlap-aware interval grouping.
3. Integrate measured spectral boxes and path observations from Audio V9, preserving channel, method and clock authority.
4. Compare alternative source separation / spatial propagation hypotheses only against genuinely independent measurements.
5. Run independent QA against the exact GitHub PR head; the historical 912-clip integrity results are not test results for newly published code.

**No audio content is published, no inference of named events is needed, and no production deployment or independent physical source attribution is claimed.**


## Generating new private listening clips from a v0.2 scan plan

A new `spash_v7_render.py` renders plan intervals into **new** stereo Ogg Opus derivatives, retaining source/channel provenance and per-clip SHA-256. It verifies the original input audio SHA-256 from the scan manifest, validates candidate identities and timestamp bounds, and refuses overwrite:

```bash
python3 tools/spash_v7_scan.py /private/dual_feed.ogg --output-dir /private/spash_scan --threshold 0.30
python3 tools/spash_v7_render.py --source /private/dual_feed.ogg --plan-dir /private/spash_scan --output-dir /private/spash_clips
# To test only a few candidate clips:
python3 tools/spash_v7_render.py --source /private/dual_feed.ogg --plan-dir /private/spash_scan --output-dir /private/spash_sample --max-clips 3
```

This renderer is **new code**; it is not asserted to reconstruct the original 912 clip files or identical boundaries. Opus packet rounding and source-seek implementation can shift playback duration by milliseconds. Its JSON receipt and CSV maintain original recording times, source hash, output clip hash and channel-preserving listening derivative authority. Synthetic regression `tests/test_v7_render.py` checks source SHA mismatch, exclusive output, channel count and clip hashes. The exact GitHub checkout has not yet been independently run; do not represent tests of a separate local ZIP as qualification of this branch.
