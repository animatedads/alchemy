# SPASH Rival — Claude clocks and human blind-score qualification

31 October 2026. Architecture: Tom Dyer. Timing measurements: Claude (Opus 5.5), spash-3d-acoustic, 23:10. Challenger: ChatGPT. Independent implementations.

## Historic Rival intervals (millisecond offsets; source-origin NOT YET VERIFIED)

- FD TP07 trajectory 2: 460–2820 ms, 105 selected spectral rows.
- FD TP07 trajectory 86: 940–2060 ms, 36 rows.
- FC TP28 trajectory 57: 460–6560 ms, 253 rows.

The Rival reader obtains frameMs from native Audio V9 spectral TSV column 4 and trajectory from column 3. It does not prove whether frameMs is relative to the original source file or a candidate-track window. The report does not include the track's original-file offset. These intervals are therefore NOT YET absolute-time qualified.

If and ONLY IF frameMs is original-file-relative, FD TP07 chain start 11:14:49.000 gives FD trajectory 2 at 11:14:49.460–11:14:51.820, and trajectory 86 at 11:14:49.940–11:14:51.060, all 10 October 2023. FC TP28 chain start 11:39:50.000 gives FC 11:39:50.460–11:39:56.560. Using Claude's camera clock correlation, this would project to FD continuous-chain 11:39:49.598–11:39:55.698 (RMS clock residual 37.9ms, before sound propagation). No real blind evaluation should use these as verified absolute selections.

## Claude measurement authority

- FD TP07 chain 11:14:49.000, 6268.250s; TP08 12:59:17.330, 6352.416s. FC TP28 11:39:50.000, 1770.357s. OGG mono 8 kHz audio is sample-identical with source MP4 A-law audio. Camera seal gaps 0.08s.
- FC_time minus FD_time = 0.9065 + 0.1331 times hours after 12:00:00, in seconds. Seven of eight overlap pairs used; RMS 37.9ms, one pair rejected. Cameras 9.43m apart limit physical propagation difference to ±27.5ms. Clock correlation pairs candidate windows but cannot reliably localise acoustic sources.
- V7 channel 1 is FC; FC_time = V7_time + 28800s. Old V9 render uses file-name times, not the continuous audio chain. Its previous classifier never ran (HTTP 429); labels were fallback rules.
- FD TP07/TP08 video minus audio offsets provisionally 114/89ms, sign pending ffprobe start_time verification. Original FD TP08 visual PTS timebase 1/90000, irregular 60/120ms samples; do not convert sample ordinal by 60ms.
- Cross-camera median speech-band coherence .038, GCC-PHAT sharpness 4.2. FD hum 103–137Hz. FC wind: >=36dB low-band 30–319Hz relative to 319–3400Hz in 300ms. FC klaxon: 32ms RMS >= median+15dB AND flatness<=.15 for >=.5s runs, plus 96ms guards, then +22dB; time-gating is preferred over notches.

## Native Rival correction

Both competitive W32 run-count and interval selection now use SpashRivalFrame.continues: same feed, StorageRef identity/digest, trajectory, strictly rising frameMs and <=250ms gap. No carried run count across source boundaries, no repeated/backwards frame times, no unobserved 250ms+ gaps. Output explicitly says TRACK_FRAME_MS_ORIGIN_UNVERIFIED and FD_CHAIN_WALL_TIME=NOT_DERIVABLE_WITHOUT_TRACK_ORIGIN_MAPPING. Prior .869–.891 merits remain experimental diagnostics and MUST NOT be reported as detection accuracy.

## Blind paired-control audit

Obtain matched random controls from the same feed, source file and time block as each candidate. Shuffle into opaque IDs and withhold source/time/strategy/pair key until Tom has labelled them. This lane's native SpashRivalBlindAudit accepts only post-review labels plus private matched key. It does NOT generate random controls or prove that the upstream selector randomised them; CONTROL_SAMPLING is a provenance attestation.

Labels: CALL, SPEECH, NOT_SPEECH, UNSURE, NOT_ASSESSABLE. Each matched pair must contain exactly one candidate and one control and share feed/file/time block/strategy. Exclude pairs where either label is UNSURE or NOT_ASSESSABLE from the assessable denominator, but retain the exclusion count. Score confirmed candidate fraction, matched random-control fraction, paired lift, candidate-only wins and control-only wins. Real scoring requires the sealed key and Tom's completed labels. No recordings, source identities, transcripts or protected metadata committed.

Native ooRexx 5.3.0 r13196 PASS: continuity regression and existing smoke/layers; blind-audit synthetic three pairs (two assessable), 1/2 candidate confirmed, 1/2 control confirmed, paired lift zero. No real labelled batch has been audited. Actual Audio V9 spectral tracks must be rerun after boundary correction; previous 200 trials are historic pre-correction results.

Outstanding: secure original-media offset mapping for each trajectory, real human blind scoring, actual source-resident Stage 2 native acoustic reconstruction, and verified audio/video synchronisation. No inference about speakers, events or source locations.
