# Aircraft Acoustic Geolocation — ooRexx precomputation and candidate-pair prototype v0.1-dev1

**Architectural direction:** Tom Dyer (aircraft acoustic sources as external geotemporal validators for SPASH/SLAM). **Code, integration specification and limited qualification:** ChatGPT GPT-6, 2026-11-05.

## Scope

A *native ooRexx* early-stage search funnel that precomputes **sampled** closest approach (CPA) and acoustic arrival time for locally projected aircraft position samples, groups predicted acoustic events per hypothetical receiver cell, and ranks **two-event** candidate flight pairs against the measured time separation of two spectral observations. A true signal-to-flight association, actual receiver position and recording epoch have **not** been established.

This prototype intentionally does not access original Paphos, Egypt or other recordings. It does not ingest ADS-B provider formats, infer receiver cell geography, perform FFT/spectrogram ridge detection, fetch terrain/meteorology, align FC/FD channels, resample audio, or claim a real-world localisation. It is neither a production ADS-B archive tool nor a full Doppler-curve optimiser.

## Run

Requires the supplied Open Object Rexx 5.3.0 r13196; only system `/bin/sh` is used for test orchestration.

```sh
sh run_tests.sh
# individual steps:
rexx src/BuildCandidateEvents.rex fixtures/receiver_relative.synthetic.tsv > predicted.tsv
rexx src/CoarsePairMatcher.rex predicted.tsv fixtures/observations.synthetic.tsv 5 5
```

The local run on the supplied Ubuntu 16.04 debug .deb's extracted interpreter passed **6 native physical assertions** and **2 synthetic end-to-end integration checks** (precomputed event-pair ranking; 3D sampled-CPA precomputation through candidate ranking). These are local, narrow assertions, *not* automated production flight data or Paphos qualification.

## Data contracts

`receiver_relative.synthetic.tsv` (TAB-separated, with exact header) contains:

`cell_id`, `flight_id`, `emission_utc_s`, `dx_m`, `dy_m`, `dz_m`, `vx_mps`, `vy_mps`, `vz_mps`.

- Coordinates are Cartesian displacement vectors **from hypothetical receiver to aircraft**, in metres, with velocities in the **same frame**. Do not pass lat/lon degrees as metres; a future ADS-B adapter must project positions and reconcile altitude datum against terrain elevation. This is not a microphone pose claim.
- Input rows are contiguous by receiver cell then flight, and monotonically increasing by emission UTC per flight. Invalid input must be refused. The crude sampled-CPA calculation chooses the input with minimum slant range; it is not sub-sample continuous CPA or acoustic peak audibility.
- `BuildCandidateEvents.rex` uses `arrival_utc = emission_utc + slant_m / sound_speed` and produces the ordered `predicted` catalogue, with `cell_id`, `flight_id`, `heard_utc_s`, `approx_speed_mps`, `cpa_slant_m`.
- `observations.synthetic.tsv` has `event_id`, `relative_s`, `approx_speed_mps`, `cpa_slant_m`, `speed_sigma_mps`, `slant_sigma_m`. Two rows sorted by observation-relative time. Speed/range measurements are uncertain inferred observables, NOT truth.
- `CoarsePairMatcher.rex` needs receiver-grouped and ascending acoustic-UTC events, and searches for distinct-flight pairs whose predicted interval fits the observed interval within bounded tolerance. It infers *one common recording start clock* from both observations and ranks the retained alternatives by a dimensionless uncalibrated residual. `top_n` is bounded by 10,000.
- The result `recording_start_utc_s` is meaningful only if the input UTC reference and two candidate aircraft identities are trustworthy. It is a candidate offset, never a validated camera recording start time.

For each detected acoustic event `i`, the measurement is its **relative time in the recording** `tau_i` (seconds). For each receiver hypothesis `x` and flight `j`, the predicted time of arrival is `T_j(x)`. For two events/aircraft, the coarse clock-invariant test is

`[T_b(x) - T_a(x)] - [tau_2 - tau_1]`.

A location is plausible only if one **shared** clock offset `t0 ≈ T_a(x)-tau_1 ≈ T_b(x)-tau_2` fits both. Matching each acoustic event with an independently shifted time would destroy the method.

## Forward model for the fine pass (NOT implemented)

At acoustic *emission time* `te`, with receiver position `x`, flight position `p(te)` and compatible velocity `v(te)`, define `R = norm(p-x)`, `Rdot = dot(p-x,v)/R`, and `tr = te + R/c`. For emitted tonal component `f0`, a first-order stationary-medium model predicts `f(tr) = f0/(1 + Rdot/c)`. Actual sound-speed profile, wind, vertical path, reflection, receiver clock drift, moving microphone and engine RPM changes must be modelled or bounded. One harmonic may be explained by more than one fundamental, and short/flat ridges can remain ambiguous.

A future fine pass should interpolate flight state at emission time, resample modelled curves in **receiver time**, fit nuisance `f0`/harmonic identity without independently shifting the two events, score held-out portions and retain ranked alternatives/uncertainties. A coarse speed observation inferred from a Doppler ridge cannot simply be equated to ADS-B ground speed without accounting for model mismatch, wind and RPM variation.

## Required integration boundaries

- **Audio V9 / media methodology providers:** source-authentic audio and STFT measurements, high/low resolution passes, spectrogram ridge/continuation extraction, harmonic linkage and calibrated uncertainty. Nothing in this package manipulates original audio.
- **SPASH:** source-bound event identities, acoustic hypotheses and multi-recording clock consistency. A detected ridge is NOT automatically an aircraft or a unique physical emitter.
- **SLAM:** multi-flight location/clock hypotheses, independent evidence checking, map constraints and iterative corrections. It does not take ownership of existing Vision or Perception modules.
- **Physics World:** propagation/atmosphere/terrain geometry and eventual retarded-time, continuous-trajectory predictions; this class is only a small preliminary physics unit.
- **RT:** evidential provenance, support/undercut and human-readable claims. An ADS-B match is an external observation with its own sampling/coverage limitations, not independent proof of microphone location by itself.
- **Storage Fabric:** index flights by UTC time window, region, type and trajectory tiles. The prototype sorts receiver-event catalogue in memory; production search must use spatial and temporal pruning, not all-pairs national brute force.
- **Foreign Runtime:** if Python or compiled providers are used for mass import/indexing, call them through the existing ooRexx-owned integration boundary. No ad hoc Python orchestrator.

Private raw audio, camera footage, source paths, exact feed hashes, personal receiver coordinates and identifiable timing annotations do not belong in public GitHub. Keep flight-data licences and citation/provenance with any local datasets. This repository contains synthetic fixtures only.

## Qualification before Paphos

1. Pin original recording lineage and clock uncertainty from source-native FC/FD files (2023-10-10, 10:00–14:00), not derived video-frame indices or constant FPS assumptions. The user's measured stream PTS issue must remain explicit.
2. Confirm flights and sample coverage for the relevant date/region through historical archives. Missing or silent flights are **not** hard negatives when ADS-B coverage, aircraft sound source, or local masking is uncertain.
3. Extract at least two coherent tonal candidates (including stable harmonic and non-aircraft controls), without deleting or permanently subtracting speech candidates.
4. Use known microphone coordinates as held-out test truth when available, rather than fitting and scoring on the same information.
5. Compare a calibrated baseline (no Doppler, coarse time matching), one-event fits, and jointly clock-locked two/multi-event fits. Report rank of true location, posterior-like confidence only if calibrated, clock residuals, geographic uncertainty, false-match and abstention rates.

### Status

**Implemented / locally tested:** native 3D range, radial velocity, sound time-of-flight and constant-tone Doppler formulas; precompute sampled-CPA events from already-projected receiver-relative samples; pair interval gating; one-clock heuristic ranking with alternatives.

**Not implemented:** real ADS-B parser, lat/lon/terrain conversion, flight-data acquisition, full spectral detection, multi-event optimiser, acoustic response/occlusion, uncertainty calibration, Paphos run, independent qualification, sphere registration or production integration.

Primary demonstration: colsto's 2026-11-02 video, `https://youtu.be/4CxVxuMVkMc`. Its original code was not released. This is an independent minimal ooRexx prototype, not an implementation of the complete video method.

## v0.1-dev2 — sampled retarded-time Doppler track (2026-11-11)

`rexx src/DopplerTrackPredictor.rex fixtures/doppler_track.synthetic.tsv > /tmp/track.tsv`
streams individual source-emission samples into **received UTC**, 3D slant
range, radial speed and *unitless* frequency ratio `f_heard/f_emitted`.
The exact emitted engine frequency remains unknown; downstream ridge fitting
must solve for it rather than treating the frequency-ratio model as a measured
harmonic. The received-time transform is `t_e + R(t_e)/c`; for a stationary
receiver `f_heard/f_emitted = c/(c + radialVelocity(t_e))`.

The module checks grouped cell/flight identity, strictly increasing emission
and arrival UTC, non-zero range, numeric geometry and causal radial speed.
Output emitted before an error must be discarded unless process exit is zero.
The fixed-speed still-air model has no terrain/wind/refraction, no interpolated
kinematics across sparse ADS-B reports and no audio/PTS authority. This is a
**synthetic LOCAL_PASS prototype only**, not a 2023-10-10 Paphos acoustic match.

Source datasets: 10 October 2023 extracted ADSB.lol historical archive
provided privately by the user. A separate read-only index run reported
53,575 aircraft trace files, 48 heatmap tiles and 23 aircraft in a union of
two Paphos UTC/ROI windows (12 in 07:00–11:00, 13 in 10:00–14:00).
No full aircraft trace or recording was mounted in this chat environment.
That index is **source-reported**, not re-run or re-qualified by this package.
It is sparse: nearest reported point ~65 km from the public reference,
which is not evidence of no aircraft near Paphos. No private apartment
coordinates, per-flight inventory or user audio are committed.

### Integration authority

SPASH owns observation path hypotheses; Audio V9/Media Methodologies own
measured spectral ridges and clock provenance; Physics World owns advanced
acoustic propagation; this package only predicts scalar Doppler geometry from
external vectors. Re-use the existing Alchemy SQLite/RexxSQL provider for
provenance-bound indexed flight-track windows. For field validation, hold out
recording intervals and fit one source frequency per independent tonal ridge,
allowing hypotheses about clock offset, aircraft trajectory uncertainty,
reflections and observer position. Model predictions are not extra microphones.
