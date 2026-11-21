# Moonsault v0.1 — celestial visibility/observation boundary (2026-11-05)

**Status:** Source and test candidate on draft PR #131; not yet runtime qualified.
**Motivation:** Sydney night reported fully cloud-covered with no stars visible; photographs were attempted but have not reached the Moonsault conversation. This is an observational scenario, not a measured meteorological dataset.

## Provider authority

`.MoonsaultEphemeris~sunMoon(utc, latitude, longitude)` returns **predictions** (ISO UTC preserved; Unix-seconds overload additive). It has no camera, cloud map, cloud-cover measurement, observed bearing, exposure or confidence input. The existing `visibilityCandidate`, `aboveHorizon`, and `headingCandidate` keys are geometric eligibility flags **not observations**.

For both Sun and Moon the provider now explicitly returns:

- `visibilityBasis='GEOMETRIC_EPHEMERIS_ONLY'`
- `observedVisibility='UNKNOWN'`
- `observationStatus='NOT_OBSERVED'`
- `cloudCoverStatus='UNKNOWN'`

The top-level record likewise has `visibilityBasis`, `skyObservationStatus` and `cloudCoverStatus`. These fields are provenance only: **no celestial coordinates, candidates, refraction or illuminations were altered.** Never populate these fields with a guess about weather.

## Required SLAM450 overcast scenarios

SLAM owns capture, identification, candidate-matching, heading corrections, battery ledger, flight-book and audit.

| Scenario | Ephemeris prediction | Sensor observation | SLAM expectation |
|---|---|---|---|
| Cloudless daytime | Sun above horizon | Valid observed Sun | May correct heading after all existing checks |
| Moonlit night | Moon candidate true | Valid observed Moon | May correct heading after all existing checks |
| Entirely overcast night | Moon candidate true | Zero detected celestial bodies | No sky heading, no sky fix and no celestial-derived position |
| Moon under horizon | Moon candidate false | Zero detected Moon | No Moon heading/fix |
| Harbor building/aircraft light | Candidate may be true | Unmatched/false detection | Reject without star attribution or sky fix |
| Clouds disperse | Predictions unchanged | Real body successfully reacquired | Resume only on genuine image detection, without retroactive fixes |
| No race clock | No valid sky time | Any scene | Preserve no-clock behaviour and ledger |

The missing-star case must be exercised over a **sustained period**, not one isolated frame. Distinguish attempted exposures (charge according to SLAM rules) from accepted sky fixes (no accepted fix if observations are absent). Preserve normal growth of heading uncertainty and prevent synthetic confidence.

## Local Moonsault regression candidate

`tests/test_visibility_authority.rex` checks day, Moon-up Sydney night, and Moon-down Sydney night. It asserts that each may return geometric candidates **without claiming observations or weather knowledge**. This test does not itself test SLAM's overcast camera path; that remains REQ-00003173 in the slam-450 lane.

## Validation gates

1. Re-run `test_ephemeris.rex`, `test_unix_slam450.rex`, `test_visibility_authority.rex` under ooRexx 5.3.0 r13196 with rxmath.
2. Compare Moonsault astronomical numerical outputs before and after this additive metadata patch.
3. Run SLAM450 Moon-night and overcast/no-stars regression with logged heading event counts and flight-book audit.
4. Do not merge the draft PR or publish navigation accuracy claims solely from metadata and static tests.

**Ownership:** Architecture user; Moonsault source ChatGPT; SLAM450 camera/observation code Claude.
