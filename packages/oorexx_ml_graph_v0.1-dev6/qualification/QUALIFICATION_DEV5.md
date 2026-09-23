# ooRexx ML Graph v0.1-dev5 qualification

## Runtime

- ooRexx 5.3.0 r13196, Internal Test Version, 64-bit.
- ooRexx Foreign Runtime v0.22.6 for optional Python rendering.
- Python 3.13.5.
- matplotlib 3.10.8.
- NumPy 2.3.5.

## Semantic baseline

Qualified against exact ooRexx ML v0.1-dev11. The graph layer does not own wobble search, fit acceptance, normative classification, pattern identity, temporal normalization, or difference significance.

## Graph regression suite

The final dev5 suite contains 16 test programs and 129 assertions:

- MLGraph model: 14
- point/path series topology: 4
- graph views: 11
- SVG polar: 7
- SVG 3-D: 5
- SVG views/Cartesian: 10
- pattern adapter: 5
- temporal pattern adapter: 8
- temporal market graph: 4
- difference annotations: 10
- wobbly adapter: 30
- wobbly SVG: 6
- matplotlib base: 4
- matplotlib views: 5
- matplotlib temporal: 3
- matplotlib wobble: 3

All pass.

## dev11 wobble authority checks

The canonical radar fixture produces distance-to-fit 3/12 with one minimal restoring set `[B3,B6,B9]`. Graph renders those observations as a point-only `RESTORING_SET` series and retains the exact `MLWobbleSet`; it does not call a scorer or rerun exclusion search.

The ambiguous fixture produces two equally minimal restoring sets. Graph allows a caller to inspect either published set without ranking them, and `participationGraph` renders the exact `MLWobbleParticipation` objects across all minimal sets.

A no-restoration-within-bound analysis (`maxRemovals=0`) is rendered as unresolved (`distanceToFit=-1`, selected restoring set 0); Graph does not manufacture a solution.

`wobble.exclusionAuthority=DIAGNOSTIC_ONLY` is recorded in graph semantic metadata. Reassignment appears only from explicit `MLWobbleReassignment` evidence.

## Rendering checks

- Deterministic ooRexx SVG renders polar, 2-D Cartesian, 3-D/cylindrical, named projections, point-only observation sets, legends, and evidence summaries.
- Foreign Runtime -> matplotlib renders the same semantic graph objects and honors `PATH` versus `POINTS` connection topology.
- The radar example renders full-set fit, restored fit, and a separately calculated/published Track-B fit without moving fit authority into Graph.

## Compatibility

- All 28 graph source/test/example Rexx surfaces compile with `rexxc`.
- Exact ooRexx ML v0.1-dev11 upstream suite: 63/63 test files PASS.
- Existing ooRexx ML Crypto Failure Demo v0.1-dev2 contract: 15 assertions PASS unchanged against Graph dev5.
- Existing crypto demo core + Foreign Runtime/matplotlib run PASS unchanged; temporal dominant difference remains `TURN/VALUE delta=350`.

## Seal procedure

The package manifest is generated over the curated tree (excluding `MANIFEST.sha256` itself). The final zip is re-extracted into a clean directory, its manifest is verified with `sha256sum -c`, and the graph suite is rerun from that extraction before release.
