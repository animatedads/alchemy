# CCTV-ALARM-EXCLUSION-V1

The recovery target is the quiet material that is not visually obvious in the original waveform. A known internal CCTV alarm is the opposite: it is an exceptionally loud, repeated near-full-scale event. It is therefore outside the search/quality domain.

## Detection authority

Detection runs only on the original/unamplified primary PCM master, before search gain, cancellation, gating, compression or limiting. The detector uses short ffmpeg `astats` frames and proposes an alarm interval only when repeated frames both:

- approach full scale (`CCTV_ALARM_PEAK_DB`, default -0.20 dBFS); and
- exceed the robust recording RMS baseline by `CCTV_ALARM_RMS_DELTA_DB` (default +12 dB).

Hot frames are clustered across gaps up to 1.25 s, require at least four hot frames, and receive a 0.25 s guard on each edge. All thresholds are overridable for controlled qualification.

## Processing semantics

Detected time is not deleted. The primary master is zeroed over the exclusion interval and the same wall-clock interval is zeroed in the companion master. Thus source and H timestamps remain stable. For the 09:45 fixture the companion master starts 15 seconds earlier than the primary master, so source-local exclusion interval `[s,e]` maps to companion-local `[s+15,e+15]`.

The masked masters are then the only inputs from which A/B/C/D/E/I parent material and H rolling windows are derived. Consequently the alarm cannot dominate search gain, cancellation, gate estimation, rank scoring, H residual selection or listening output.

The detector writes `exclusions/campaign0945_cctv_alarm_source_master.tsv`; parent-local projections are written to `campaign0945_parent_source.tsv` and `campaign0945_parent_companion.tsv`. These manifests are included in `SAMPLES.sha256`.

## Fail-safe intent

An isolated peak is not enough. The rule is deliberately a cluster rule so loud speech or a single impact is not silently discarded merely because it clips once. The original source remains immutable; only derived campaign fixtures are masked.
