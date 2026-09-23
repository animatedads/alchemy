# Dev12 overnight 51-job echo survey findings

Evidence archive: `ed209c_dev12_echo_51jobs_2100_0530.tar.gz`  
SHA-256: `1168d49aeef2093003691cb189e4e8f00675c08bef8cb72f2001f78d4183aed0`

This is qualification evidence for the dev14 survey changes. The archive is not
embedded in the package. The figures below are derived from its 51 per-window
`LOUD_EVENT_ECHOES.tsv` files and metadata.

## Coverage

- 51/51 ten-minute windows are present, continuously covering
  `2023-10-09 21:00:00` through `2023-10-10 05:30:00`.
- All metadata rows declare schema `audio.v9.voice-recovery.loud-echo-window/2`,
  `min_abs_peak=0.001`, `min_ratio=6`, family radius `4 ms`, strong score `0.70`.
- Total admitted events: 10983.
- Trigger feed: FC=5767, FD=5216. This confirms v2 repaired the FC-only
  admission bias seen in the prior dev11 survey.

## Ambiguity is real evidence

- `MULTI_FAMILY`: 9759
- `SINGLE_FAMILY`: 400
- `WEAK`: 824
- Median strong-family count: 7 of 7.
- Median best-minus-second score margin: 0.010310403.

The family-window result must not be interpreted as a discovered source
identity. The named windows are hypothesis tests, not a prior-free echo search.

Pattern-hint counts are diagnostic only:
- `UNRESOLVED_PATTERN`: 5810
- `FD_STAIRWELL_PATTERN`: 3435
- `FC_ROAD_SIDE_PATTERN`: 968
- `MODELED_ROOM_PATTERN`: 770

## Family-boundary and cross-camera censoring

- Any named-family boundary hit: 7208/10983 (65.63%).
- Best hypothesis on its named-family boundary: 539/10983 (4.91%).
- The existing FC<->FD search is bounded to +/-35 ms. 96 rows land
  exactly at +/-35 ms; 45 of
  those have `cross_score >= 0.70`. These are censored measurements, not
  evidence that 35 ms is the true unconstrained delay.

Dev14 v3 therefore records `cross_boundary` and the cross-search radius
explicitly rather than silently publishing the endpoint as ordinary geometry.

## Local FC zero/silence evidence

369 event rows have both `peak_fc=0` and `baseline_fc=0` while FD
continues to trigger. In event evidence this spans approximately
`2023-10-10T00:06:14.398125` through
`2023-10-10T00:34:31.263125`. Chunks 20 and 21 are entirely in
this condition. The campaign does not contain raw PCM, so this is described as
local zero/silence evidence rather than an asserted cause.

V3 records local feed-nonzero and baseline-coverage evidence so downstream
geometry can fail closed when one feed is unavailable.

## 04:16:46 calibration candidate

The earlier screenshot alignment placed the sharp visible event at approximately
`2023-10-10 04:16:46.4`. Dev12 chunk 44 contains four events within +/-250 ms.
The two strongest cross-camera rows are:

- `04:16:46.342750`: cross score 0.809003760, FC trigger, FD leader,
  `fd_minus_fc=-31.375 ms`, best named-window score 0.832199084.
- `04:16:46.528000`: cross score 0.968319389, FC trigger, FC leader,
  `fd_minus_fc=+27.750 ms`, FC peak 0.992201805,
  best named-window score 0.952336700.

The latter has all seven named families strong. It is therefore a particularly
useful real transient for comparing named hypotheses with the new v3 prior-free
6..80 ms recurrence peaks, but its v2 best-family label is not ground truth.

## Why v3 adds prior-free recurrence peaks

Applying the existing constant-delay wobble model to observations selected from
one named +/-4 ms family window can appear well fitted partly because the
observations were pre-constrained by that same window. V3 retains all v2 named
hypotheses unchanged but also emits the strongest same-feed matched-filter
recurrence peaks over 6..80 ms without consulting the named room geometry.

Those prior-free peaks are the appropriate input for recurrence clustering and
model-relative wobble tests of whether one or several acoustic paths explain
repeated real events.
