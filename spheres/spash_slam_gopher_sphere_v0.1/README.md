# SPASH SLAM sphere v0.1

Architecture: Tom Dyer. Initial independent implementation and documentation: ChatGPT GPT-6, 2026-10-30.

Canonical package: packages/oorexx_spash_slam_v0.1-dev1.

OBS != LIKE != PATH != PHYSICAL SOURCE.

An acoustic node carries exact source/sample/time geometry, band, processing-method identity, frequency, optional pitch, spectral pattern, energy and optional location hypothesis. SPASH derives a likeness-family identity from compatible patterns, proposes temporal continuation, allows independent overlapping paths, and produces source-referenced replay plans. None of those operations requires naming the sound.

The graph refuses unaligned cross-feed and cross-method continuation; pattern resemblance across sources does not imply one physical emitter. Spectral-bin incompatibility is INCOMPARABLE rather than dissimilar. Virtual microphone results are MODEL_ONLY predictions, not independent captured measurements. An unadmitted replay path is rejected instead of silently spliced. Method-foundation IDs retain dependency information.

Experiment order: admit measured blocks and source/method provenance; compute likeness; propose competing graph continuations; select and retain alternative paths; emit exact sample/band replay plans; test spatial hypotheses against held-out real measurements if they exist; preserve negative results and model uncertainty.

Qualification: 40 positive and nine negative admission tests PASS using ooRexx 5.3.0 r13196 on 2026-10-30. These are synthetic fixtures, not field audio or independent acoustic triangulation.

Next: source-hashed Audio V9 input adapter, drift-resistant family identity, calibrated branch scoring, chunk-halo continuation, SQL graph indexing, independent spatial model comparison and an actual governed waveform renderer. No changes to SLAM, Body SLAM or JCL ownership.

## Example-driven acoustic search extension (2026-10-30)

A caller may supply a short WAV **as an acoustic specimen**, without naming an event. The Python reference provider `tools/spash_find_similar.py` extracts normalized log-frequency spectrotemporal blocks, selects active 0.96-second template subsequences, searches candidate WAVs under limited tempo/coarse-spectral shift experiments, and reports ranked source-verified timestamps. Do not treat the numerical score as a probability. The source itself is never committed.

Native `SpashExampleSearch.cls` compares same-foundation observation subsequences across source IDs, with bounded speed variation, interval provenance, ranked alternatives and overlap suppression. Cross-channel geometry and real pitch-transposition calibration remain open. Requirements: never use a single whole-clip mean as the only query, never present an exact self-overlap as discovery, never interpret spectral likeness as a named source or spoken transcript, and never claim independent evidence where the method or recording is shared.


## Spectral distance correction and partial replay boundary

Correctly normalized comparison is `1 - mean_over_time(sum_over_frequency(abs(Q-C))/2)`; the frequency-bin count is NOT another denominator. The initial GitHub WAV publication had an erroneous band-count normalization, encouraging false positive likeness. Requalified local reference distinguishes a deliberately copied 2.56–3.52 s private passage shifted to 6.56–7.52 s, score about 0.968, from white-noise and sine-sweep negative controls (no accepted matches at threshold 0.8). These are algorithm-dependent scores, not likelihoods or source identities.

A match-only listening renderer preserves exact original source sample indices and source + derived clip SHA-256, refuses changed sources and refuses overwrites. It is a PCM crop of the source, NOT spatial extraction, source-separated audio, hallucinated microphone evidence or forensic authentication. Private source material and derived WAVs stay out of the Git repository.

The published source still requires independent checkout qualification before merge. The locally qualified ZIP plus its SHA-256 manifest is a separate, explicit provenance lineage.


## User validation of ranked speech-containing acoustic matches (2026-10-30)

The user listened to the three SPASH same-recording matches previously presented from their private example and reported that **all three were valid matches to human-voice speech extracted from audio intercepts**. This is external user review of speech presence in those candidate passages, not independent algorithmic speech recognition or verified same-speaker identity. The first two comparisons substantially revisit the same interval pair in opposite directions, so avoid treating the three ranked matches as three independent physical observations. No recall estimate is available for unreviewed candidates or excluded results.

The separate, local-only `spash.feedback.receipt/0.1` evidence prototype binds each review to a canonical source-report hash and to its ranked match hash, with labels `HUMAN_SPEECH_PRESENT`, `NOT_HUMAN_SPEECH`, `UNDETERMINED`. It preserves algorithm score and external review separately, rejects altered/duplicate reviews and retains speaker, words, physical source and location as NOT_ASSESSED. The privacy-sensitive user-specific receipt and source audio are **not** placed in Git. Local feedback qualification was 16/16; independent exact-GitHub-checkout qualification and integration into the PR runtime remain outstanding.


## V7 full-duration candidate library; release policy

Private V7 study: 8h39m surveyed; 912 candidate audio intervals preserved as listening derivatives, 463 stronger voice-like, 242 intermediate and 207 faint/ambiguous. The 2:58 user-confirmed positive is included. Human feedback says every clip listened to thus far in hour 4 contains a verbal, without a supplied reviewed count. This is encouraging positive-review evidence, **not** certified full-corpus accuracy, recall or physical speaker identity.

Public Git work is *code and method only*. `packages/oorexx_spash_slam_v0.1-dev1/docs/V7_CORPUS_METHOD.md` describes the documented historic pass. The new `spash_v7_scan.py` is an experimental streamed reference, not a proven byte-identical recreation of the earlier 912-clip segmentation; `spash_v7_validate.py` audits the original private archive offline. `spash_review_feedback.py` keeps measured likeness and human speech-presence feedback on separate, hash-bound evidential tracks. Original intercept, listening clips, private hashes and annotations are not committed.
