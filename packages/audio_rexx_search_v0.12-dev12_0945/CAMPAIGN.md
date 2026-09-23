# Audio Rexx Search v0.12-dev12 — 09:45 campaign

## Camera authority

The 09:45 campaign preserves the established camera-role split:

- **primary/main camera**: `20231010_093912_tp00006_original.ogg`, starts 09:39:12 and overlaps the whole campaign;
- **companion sequence**: `20231010_090927_tp00023_original.ogg` -> `20231010_094521_tp00024_original.ogg`, continuous at the 09:45:21 seam.

## 09:45 parent and H masters

Target centre is 09:45:00.

- primary target offset in tp00006: `348 s`;
- A-E parent source: tp00006 `258..438` -> `09:43:30..09:46:30`;
- H source master: tp00006 `78..618` -> `09:40:30..09:49:30`.

The companion keeps the established ±15-second alignment margin:

- H companion master: `09:40:15..09:49:45` (570 s);
- tp00023 contribution: offset `1848`, duration `306` -> `09:40:15..09:45:21`;
- tp00024 contribution: offset `0`, duration `264` -> `09:45:21..09:49:45`;
- A-E companion parent: master `180..390` -> `09:43:15..09:46:45` (210 s).

## H pursuit

| H view | primary source wall clock | companion wall clock |
|---|---|---|
| m180 | 09:40:30..09:43:30 | 09:40:15..09:43:45 |
| m90 | 09:42:00..09:45:00 | 09:41:45..09:45:15 |
| p0 | 09:43:30..09:46:30 | 09:43:15..09:46:45 |
| p90 | 09:45:00..09:48:00 | 09:44:45..09:48:15 |
| p180 | 09:46:30..09:49:30 | 09:46:15..09:49:45 |

H retains the dev7 additive `h_voice_mix.wav` output in every parent/window.

## Quality targets

v0.12-dev12 activates `AUDIO-QUALITY-TARGETS-V2` for A-E/I and H scoring. `reference/QUALITY_CORPUS.tsv` currently lists four distinct canonical 16 kHz mono PCM16 references: the two prior contrast references plus quiet and high-register windows from the user-supplied 2026-09-08 WhatsApp recording. No denoise, compression, gating, loudness normalization or peak normalization is applied to any reference. Byte-identical duplicate uploads are provenance only and do not increase corpus weight.

Because the reference material changed, dev8 scalar/reference-distance scores are **not numerically comparable** with dev7 or earlier search scores.

## ED209i / Strategy I

ED209i joins this campaign as a sixth persistent CPU lane. Strategy I is intentionally biased to cancellation strengths 0.60, 0.75 and 1.0, with bounded gain/filter/gate variation and no first-stage echo/compression. Its purpose is to surface quiet high-cancellation voice residuals as independently ranked evidence and as useful parents/residuals for H additive mixing.

## CCTV alarm exclusion for the 09:45 rerun

Before parent/H extraction, `prepare_samples.sh` scans the exact 540-second original/unamplified tp00006 master for the characteristic repeated near-full-scale CCTV alarm. Any detected cluster is written to `exclusions/campaign0945_cctv_alarm_source_master.tsv` and zeroed in-place in the derived primary master. The identical wall-clock interval is excluded from the companion master using the established +15-second local offset. No timeline is collapsed.

A/B/C/D/E/I and H therefore receive only the masked campaign masters. The immutable original Ogg recordings are never modified.
## dev11+ prepared-fixture deployment invariant

The 09:45 fixture is sealed by `SAMPLES.sha256`. `verify_prepared_samples.sh` is authoritative at the controller boundary and runs before remote node contact. It verifies every sealed WAV/TSV hash, exact sample counts, the `cctv.alarm.exclusion/1` schema, ordered in-range source-master alarm intervals, and byte-exact parent-source/parent-companion projections. Because the alarm is known to occur in this campaign, zero detected intervals fail closed by default.

The intended full rerun is therefore: prepare -> verify/inspect exclusions -> `deploy_all.sh --full --no-prepare --reset-state`. This changes controller admission only; A-E/I/H DSP, ML, Pareto and ranking semantics are unchanged.

