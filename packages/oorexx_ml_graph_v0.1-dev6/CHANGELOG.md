# Changelog

## v0.1-dev6

- Adds a sibling semantic raster/overlay object model: `MLImageScene`, `MLImageLayer`, source adapters, styles and primitive geometry.
- Adds line, polyline, polygon, rectangle/rounded rectangle, ellipse, circle, marker/cross and text primitives.
- Adds independent stroke alpha, fill alpha, overall style opacity and layer opacity; overlays are ordered and retain caller/upstream evidence.
- Adds `PIXEL` and `NORMALIZED` coordinate spaces without rewriting source geometry.
- Adds presentation-only render scaling and default clipping to the source image extent.
- Adds `MLVisionSurfaceImageSource`, consuming arbitrary-size ooRexx Vision dev14 `VisionSurface` objects and their public indexed-colour model while retaining the exact surface as evidence.
- Keeps V5V temporal decoding and high-resolution evidence escalation in ooRexx Vision; ML Graph begins at the decoded `VisionSurface` boundary.
- Adds deterministic run-length SVG raster rendering plus vector overlays.
- Adds an optional Foreign Runtime -> Python -> Pillow PNG renderer; no Python proxy becomes image semantic state.
- Adds arbitrary-dimension Vision/V5V overlay regressions and a technical overlay example.

## v0.1-dev5

- Rebases graph qualification from ooRexx ML v0.1-dev10 to v0.1-dev11.
- Adds `MLGraphSeries~connection` with `PATH` and `POINTS`; existing callers retain `PATH` by default.
- Adds `MLWobbleGraphAdapter` consuming `MLWobbleAnalysis` without repeating fit-restoration search or declaring observations bad.
- Splits a selected *published* restoring set into explicit point-only diagnostic evidence while retaining each original observation as point evidence and the exact `MLWobbleSet` as series evidence.
- Maps published linear-fit slope/intercept evidence into presentation line geometry; Graph never invokes a scorer or calculates a fit.
- Adds `participationGraph` for `MLWobbleParticipation` across all equally minimal restoring sets. Graph does not rank ambiguous minimal sets.
- Adds explicit reassignment annotations retaining exact `MLWobbleReassignment` objects; diagnostic exclusion remains distinct from later semantic disposition.
- Records `wobble.exclusionAuthority=DIAGNOSTIC_ONLY` and renders distance-to-fit, normalized distance, evaluation count and upstream normative classification as evidence summaries.
- Adds a 2-D Cartesian SVG legend and point-role markers needed to distinguish retained observations, restoring-set observations, full-set fit, restored fit and reassigned-model fit.
- Extends the Foreign Runtime -> matplotlib provider with point-only topology and matching wobble-role markers.
- Replaces the dev11 radar demo's hand-SVG concept with graph-backed SVG/matplotlib examples and adds an ambiguous-restoring-set participation example.

## v0.1-dev4

- Adds `MLGraphView`, an explicit presentation projection over already-existing graph axes.
- Adds named cylindrical views: `SHAPE`/`TOP` = axis 1/2, `TIME_X`/`SIDE_X` = axis 1/3, and `TIME_Y`/`SIDE_Y` = axis 2/3.
- Adds generic Cartesian `XY`, `XZ`, and `YZ` axis-pair views without deriving new semantic coordinates.
- Makes cylindrical `SHAPE` use `aspect=EQUAL`, preserving the geometry of circles and other spatial relationships instead of stretching them to the viewport.
- Extends the deterministic SVG reference renderer to native 2-D Cartesian graphs and axis-pair projections of 3-D graphs.
- Extends the optional Foreign Runtime -> matplotlib renderer to the same named views and equal-aspect `SHAPE` semantics.
- Makes matplotlib honor `MLGraphSeries~semanticKey` so a channel retains presentation identity across overlays, matching the SVG renderer.
- Adds a one-graph/four-view dev10 temporal-hash example and view/model/SVG/matplotlib regressions.
- Preserves the dev3 difference-authority boundary unchanged: views project presentation only and do not locate or recompute ML differences.

## v0.1-dev3

- Adds `MLGraphAnnotation` with retained evidence and an explicit non-locatable `SUMMARY` contract.
- Adds `MLGraphDifferenceAdapter` for `MLPatternHashDifference` and `MLTemporalPatternDifference` published summaries.
- Records `difference.location=UNPUBLISHED` because ooRexx ML v0.1-dev10 does not publish the dominant point/segment index; Graph does not reverse-engineer one.
- Renders summary evidence through both the deterministic SVG reference renderer and optional Foreign Runtime -> matplotlib provider.
- Updates polar and cylindrical market examples to carry their upstream difference object into the graph.
- Adds difference-authority, annotation-model, SVG-escaping and matplotlib annotation regressions while preserving dev2 adapters unchanged.

## v0.1-dev2

- Rebases qualification from ooRexx ML v0.1-dev9 to v0.1-dev10.
- Adds `MLGraph~cylindricalTime`, declaring `CYLINDER_X`, `CYLINDER_Y`, and explicit `TIME` axes.
- Adds `MLTemporalPatternGraphAdapter` consuming published `MLTemporalPatternHash~points` without recomputing normalization, angle, radius, or time.
- Retains originating temporal hash as series evidence and originating cylindrical point as point evidence.
- Extends deterministic reference SVG rendering to 3-D Cartesian/cylindrical graphs; the renderer only performs view scaling/projection.
- Adds semantic series keys so repeated channels retain presentation identity across overlaid patterns.
- Adds synthetic market cognitive-reveal examples for reference SVG and optional Foreign Runtime -> matplotlib rendering.
- Adds temporal-adapter, 3-D SVG, market-contract, and matplotlib-temporal regressions.

## v0.1-dev1

- Introduces renderer-neutral `MLGraph` technical visualisation objects.
- Adds named axes with semantic roles, including explicit `TIME` support and 3D Cartesian graphs.
- Adds semantic points/series/grid and retained evidence references.
- Adds `MLPatternGraphAdapter` consuming existing `MLPatternHash~polarPoints` without re-normalization.
- Adds deterministic polar SVG reference renderer with retained sample dots.
- Adds optional matplotlib 2D polar/Cartesian and 3D renderer through Foreign Runtime resident Python objects.
- Adds qualification tests and dev9 pattern-hash replacement example.
