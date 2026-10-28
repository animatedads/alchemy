# Audio spectral integrity — controlled falsification protocol (v0.3)

## Research question

Can a known two-source alternating-frequency weave be distinguished from (1) a single ordinary voice, (2) a notched single voice, and (3) an ordinary simultaneous two-voice overlap, without knowing the reference words or condition? This experiment is about detection *limits* and false positives; it is not a finding about private recordings.

## Competing hypotheses

- H0a: one voice whose harmonics have been selectively removed (loss of expected harmonics without multiple streams).
- H0b: ordinary overlapping voices, including room/codec effects.
- H1: frequency-domain engineered weave of two exact known voice sources.

These controls are not all physical nulls. Recorded natural multi-speaker conversation, telephone codec, outdoor wind and loudspeaker playback must be qualified separately before external classification.

## Procedure

1. Retain two separately consented, independently recorded reference utterances A and B; align duration/rate/channel geometry. Retain immutable hashes and consent/provenance.
2. Run `python3 src/blind_trial.py A.flac B.flac PRIVATE_OUTPUT --seed 7301 --ceiling-hz 8000`. This exports four anonymous stereo FLACs, `PRESENTATION.json`, `RESPONSES_TEMPLATE.csv`, and a local-only chmod 0600 `PRIVATE_KEY.json`. Do not upload the private key. Trial generator refuses overwrite.
3. Obtain free text transcriptions before mentioning suspected phrases. Collect confidence, perceived number of voices, and uncertainty. Randomize playback order per listener outside the deterministic code mapping; control headphone/device, level and trial fatigue.
4. Lock responses and hash them; only then open `PRIVATE_KEY.json`. Report confusion matrix and false-positive rate with denominator and listening/codec conditions.
5. For engineering qualification, use `oracle_template_projection` with exact unprocessed A/B to establish known A/B coefficients in odd/even groups. This diagnostic is unavailable for an unknown clip and cannot be used for attribution.
6. Compare whole-recording FFT buckets to 4096-point/quarter-hop WOLA buckets, and sweep origins 0,25,50,75 Hz. Changing perceived content or harmonic strength is not a source-count claim.

## Controls and safeguards

- Compare single filtered source with two-source weave: expected harmonic gaps are not proof of two sources.
- Compare ordinary two-voice overlap with engineered weave: both may yield different band content.
- Gross RMS matching is not perceptual loudness normalization; peak limiting scale is stored with each trial condition and potential clipping must be documented.
- Avoid training listeners with candidate phrases before free transcription. Record both agreement and disagreements without adjudicating vocabulary from expectation.
- Never treat a TTS demo as evidence of any particular person's actions or motives. Preserve original media separately; never distribute private child audio or location data in public repo.

## Gate before any source-classifier claim

Independent holdout, known natural overlapping speech, codec/room/loudspeaker variations, matched method/phase settings, performance distributions with uncertainty and blind transcriptions. A single-source notched recording must remain a first-class false-positive control. No assertion of forensic validation follows from the synthetic tests.
