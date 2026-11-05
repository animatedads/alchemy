# SLAM 450 v0.93 — race clock, Sun and Moon headings from Moonsault, recall

Architecture: Tom Dyer
Coding: Claude (Opus 5.5) (SLAM 450 v0.93: race clock, Sun/Moon in the camera, the sky heading, the Moonsault adapter, target recall, triangulation, tests, auditors, runs); ChatGPT (GPT-6) (Moonsault Sun/Moon provider, `packages/oorexx_moonsault_v0.1`, on main)
Written by: Claude (Opus 5.5), 2026-11-05

Runs: Anthropic cloud workspace, ooRexx 5.3.0 r13196, 2 cores, SLAM flying alone (no LLM, no API spend) unless stated. v0.92's evidence stays in `oorexx_slam450_v0.92/evidence`.

## What changed since v0.92

1. **Race clock.** A new last argument gives the UTC start, e.g. `2026-11-04T23:00:00Z`; each tick adds 1 s. Empty means no clock and no sky, so older races are unchanged.
2. **Sun and Moon from Moonsault.**
   - `Slam450MoonsaultEphemeris` calls `.MoonsaultEphemeris~sunMoon(utcIso, lat, lon)` from `packages/oorexx_moonsault_v0.1`, which `MOONSAULT_SRC` points to.
   - It converts SLAM's Unix-second clock to Moonsault's ISO string and maps the fields: altitude true and refracted, azimuth, `aboveHorizon`, the Moon's `visibilityCandidate` (night only, Sun below −6°), `headingCandidate`, illuminated fraction, elongation, error budgets, source tag and status.
   - `Slam450Ephemeris` is a stand-in with the same shape, used only when Moonsault is absent. The race header records which one ran.
3. **In the camera.** The Sun (`S`, white) and a visible Moon (`M`, pale grey) are drawn as 3 × 3 dots, painted before land and structures so those hide them. The visual-fix grid treats them as unknown points.
4. **Sky heading** (SLAM's own observation; Moonsault stays a prediction).
   - Every 10 s, offset 5 s from the visual fix, SLAM takes the circular-mean column of the dot in its own view.
   - It gets the body's azimuth from the ephemeris at its flight-book position.
   - It writes heading = azimuth − bearing as `SUN_HEADING` or `MOON_HEADING`, if the body is 5–70° up and the result is within 20° of the book.
   - Each observation costs 0.03 (VISUAL ledger, `sky_fixes` column). Position is never taken from the sky.
5. **LLM briefing.** When the clock runs, the briefing names the two dots and says they work as a compass, and the UTC time is given each tick.
6. **Recall and triangulation** (from v0.92's plan).
   - A target too small to range leaves a bearing line in the flight book; two lines at least 10° apart within 60 s cross at the target (`SLAM_TRIANG`).
   - Search mode `RECALL` flies to the book's entry when the chosen target has been out of view for 3 s. Entries expire after 45 s for moving targets and 120 s for still ones.
7. **Auditors.**
   - `audit_belief450.py` rebuilds every sky heading from `_skyfix.csv`.
   - `audit_battery450.py` counts `sky_fixes` at 0.03.
8. **V5V size tool.** `bin/v5vsize450_visualfix.rex` now uses the current V5V codec in `packages/oorexx_vision` (dev14's missing `~between` is fixed upstream). It runs a full encode/decode round trip.
9. **Visual-fix grid files** are rewritten one letter per point (VISUALFIX2), halving them to 4.0 MB; the loader reads both formats.

## Results

### Ephemeris against independent code
`tests/check_sky450.py` compares against PyEphem 4.2.1 at 400 instants through 2026, Sydney:

| | Sun alt / az | Moon alt / az | Moon illuminated fraction |
|---|---|---|---|
| Moonsault (via the adapter) | 0.0085° / 0.0087° | 0.062° / 0.097° | within 0.002 |
| Stand-in | 0.010° / 0.010° | 0.061° / 0.090° | within 0.002 |

Moonsault's own budgets are 0.10° (Sun) and 0.50° (Moon). Its own regression test passes 6 reference cases.

### Heading from the sky (HARBOUR, wings, visual fix and recall on, 4 seeds)

| | Heading error median / worst 10% | Sky observations accepted | Position error median | Claims |
|---|---|---|---|---|
| No clock | 0.90° / 4.7° | — | 24.3 m | 19 |
| Sun (10:00 AEDT) | 0.20° / 1.4° | 615 / 616 | 23.9 m | 19 |
| Moon night (23:00 AEDT 18 Nov, Moon 36° up, 60% lit, Moonsault) | 0.20° / 1.5° | 592 / 594 | 23.5 m | 19 |

- The sky corrects heading. Position is set by the visual fix, so it doesn't move.
- The heading gain matters most where the visual fix fails: open sea and long flights.
- On seed 45046 the Moonsault Sun run matched the stand-in Sun run exactly.

### Recall (HARBOUR, visual fix on, 4 seeds; claims by Haiku's two aircraft out of 20)

| | SLAM alone, sweep | SLAM alone, recall | Haiku navigating, recall |
|---|---|---|---|
| Quads | 2 | 2 | 7 |
| Wings | 8 | 8 | 16 |

- 126 of the 137 recall flights went to targets Haiku had written into the book as `seen`.
- SLAM's own triangulation is weak: median error 100–111 m.

### Audits
All checks pass on every v0.93 batch: sky comparison 32, Moon and Moonsault Sun 20, recall 32, Haiku with recall 32. They cover squad, battery, target movement and flight book.

## Known limits
- **No night lighting.** At night the scene is drawn in daytime colours; the Moon is a grey dot on a pale-blue sky and targets are as visible as at noon. Night lighting is a design decision still open.
- **Moonsault's Moon** is offered only at night (its visibility rule). There is no daytime Moon heading.
- **Weak triangulation:** wider-spaced bearing lines and averaging several crossings are the next step.
- **Moonsault branch `moonsault/slu450-unix-time-v093`** adds Unix-second input and keeps ISO. The adapter works with either.

## Self-score
8/10. The sky heading is checked against independent code, audited and measured by day and by night. Against: three small first-pass bugs in the stand-in (`E` and `e` are the same Rexx name, an inverted illuminated fraction, the ISO date format), all caught by the tests; and a missing return value in the flight book that cost one rerun of a batch.
