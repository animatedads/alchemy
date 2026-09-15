# ooRexx ML Graph v0.1-dev5

A technical-visualisation component for the ooRexx ML Toolset. It explains ML evidence without becoming the authority for what that evidence means.

The core rule remains:

```text
ML algorithm / evidence
        |
        v
    MLGraph objects             semantic coordinates, axes, series, grid, evidence
        |
        v
    MLGraphRenderer             presentation boundary
       / \
      /   \
   SVG     Foreign Runtime -> Python -> matplotlib
(reference)                         (optional)
```

**Renderers never decide equivalence, normalization, timing, or pattern identity.**

## dev5: model-relative wobble and restoring-set evidence

`MLWobbleGraphAdapter` consumes ooRexx ML v0.1-dev11 `MLWobbleAnalysis` objects. It does not decide which observations are wrong, noisy, irrelevant, or disposable. It maps the analysis already published by ML into an explanatory graph:

```text
observations + MLWobbleAnalysis
          |
          v
MLWobbleGraphAdapter
  retained observations       POINTS
  selected restoring set      POINTS
  published full-set fit      PATH, if slope/intercept are published
  published restored fit      PATH, if slope/intercept are published
  distance/normative summary  retained evidence
          |
          v
SVG or Foreign Runtime -> matplotlib
```

The selected restoring set is always one of the exact minimal sets published by dev11. If several minimal sets exist, the caller names which set to inspect; Graph does not rank alternatives. `participationGraph` presents dev11's `MLWobbleParticipation` evidence across *all* minimal sets.

A restoring set is rendered as **temporarily excluded diagnostic evidence**, never as deleted/bad data. The graph records `wobble.exclusionAuthority=DIAGNOSTIC_ONLY`. Explicit later `MLWobbleReassignment` decisions can be attached as annotations.

Dev5 also adds `MLGraphSeries~connection`: existing series default to `PATH`, while unordered measurement sets can declare `POINTS`. This prevents the renderer from inventing a line through observations that upstream ML never declared as a path.

The canonical radar example from dev11 is now rendered through Graph rather than hand-written SVG in `examples/wobbly_fit_graph.rex`. The same three returns that restore Track A can be explicitly reassigned to Track B, whose fit is separately calculated by the upstream ML scorer and supplied to Graph as another published assessment.

## dev4: one semantic scene, several honest views

`MLGraphView` makes projection explicit without creating a derived ML object. A view names which existing axes a renderer should present. For a cylindrical temporal graph:

```rexx
g=.MLTemporalPatternGraphAdapter~graphForHash('same evidence',h)
r=.MLGraphRenderers~byName('SVG')

g~render(r,'native.svg')
g~render(r,'shape.svg',g~view('SHAPE'))
g~render(r,'time_x.svg',g~view('TIME_X'))
g~render(r,'time_y.svg',g~view('TIME_Y'))
```

The views mean:

- `SHAPE` / `TOP`: original `CYLINDER_X` against original `CYLINDER_Y`; `aspect=EQUAL` so a circle stays a circle.
- `TIME_X` / `SIDE_X`: original `CYLINDER_X` against original `TIME`.
- `TIME_Y` / `SIDE_Y`: original `CYLINDER_Y` against original `TIME`.
- `NATIVE`: the original 3-D graph.

Generic 3-D Cartesian graphs also expose `XY`, `XZ`, and `YZ`. No view resamples points, converts values, derives time, or replaces evidence references. The deterministic SVG renderer now supports these 2-D Cartesian views directly; matplotlib provides the same view contract through Foreign Runtime.

`MLGraphSeries~semanticKey` is now honored by both renderers so the same semantic channel keeps the same presentation identity across overlays; line role still distinguishes `PRIMARY`, `EQUIVALENT`, `CONTRAST`, and related roles.

## dev3: evidence annotations without semantic re-derivation

dev3 adds `MLGraphAnnotation` and `MLGraphDifferenceAdapter` so an ML difference object can travel with the graph and be rendered as explanatory evidence.

The first supported annotation kind is deliberately only `SUMMARY`. ooRexx ML v0.1-dev10 publishes dominant difference magnitude and categories, but it does **not** publish the exact point/segment index at which the dominant disagreement occurred. Graph therefore records `difference.location=UNPUBLISHED` and refuses to manufacture a location by re-running ML difference logic.

```rexx
d=schema~difference(hA,hB)
g=.MLTemporalPatternGraphAdapter~overlay('comparison',.array~of(hA,hB),.array~of('A','B'))
.MLGraphDifferenceAdapter~addTemporalSummary(g,d)
g~render(.MLGraphRenderers~byName('SVG'),'comparison.svg')
```

The annotation retains the exact `MLPatternHashDifference` or `MLTemporalPatternDifference` as evidence. Both the deterministic SVG renderer and the optional matplotlib provider render the published summary, while neither decides where the difference occurred.

## dev2: cylindrical temporal patterns

dev2 rebases the graph component on ooRexx ML v0.1-dev10 and adds a direct adapter for `MLTemporalPatternHash`.

`MLTemporalPatternGraphAdapter` consumes the hash's already-published cylindrical points:

```text
MLTemporalPatternSeries
        |
        v
MLCylindricalTemporalPatternSchema
        |
        v
MLTemporalPatternHash
  x / y / height points
        |
        v
MLTemporalPatternGraphAdapter
        |
        v
MLGraph cylindricalTime
  CYLINDER_X / CYLINDER_Y / TIME
```

The adapter does **not** recalculate radius, event angle, time normalization, channel scaling, bearing, elevation, or turn. Each graph series retains the originating temporal hash as evidence; each graph point retains the originating `MLCylindricalTemporalPoint`.

The deterministic SVG reference renderer now supports both 2-D polar graphs and 3-D Cartesian graphs. For declared cylindrical graphs it draws a cylinder guide and performs only view scaling/projection. The optional matplotlib provider remains behind Foreign Runtime.

## Public objects

- `MLGraphAxis`
- `MLGraphPoint`
- `MLGraphSeries` — semantic key plus explicit `PATH`/`POINTS` connection topology; `PATH` remains the compatibility default.
- `MLGraphGrid`
- `MLGraphView` — `NATIVE` or an explicit existing-axis pair, with `AUTO`/`EQUAL` aspect policy.
- `MLGraphAnnotation` — currently `SUMMARY`, with retained source evidence and `locatable = false`.
- `MLGraph`
  - `polar`
  - `cartesian2`
  - `cartesian3`
  - `spaceTime`
  - `cylindricalTime`
  - `view(name)`
- `MLPatternGraphAdapter`
- `MLTemporalPatternGraphAdapter`
- `MLGraphDifferenceAdapter` — consumes published difference fields without locating/recomputing them.
- `MLWobbleGraphAdapter` — consumes dev11 fit-restoration, minimal-set, participation, normative and reassignment evidence without performing wobble search.
- `MLGraphRenderer`
- `MLGraphSvgRenderer`
- `MLGraphMatplotlibRenderer` (optional)
- `MLGraphRenderers`

## Market cognitive-reveal demo

`examples/cylindrical_market_graph.rex` uses the synthetic dev10 market fixture where two nominal PRICE traces look almost identical while RELATIVE/FX/VOL behaviour differs sharply. The graph renders the actual dev10 temporal-hash geometry; similarity is still decided by `MLCylindricalTemporalPatternSchema~difference`, not by the renderer.

```rexx
g=.MLTemporalPatternGraphAdapter~overlay('market reveal', -
    .array~of(hA,hB), -
    .array~of('A base','B price lookalike'), -
    .array~of('PRIMARY','CONTRAST'))
g~render(.MLGraphRenderers~byName('SVG'),'market.svg')
```


## Same temporal evidence, four views

`examples/cylindrical_market_views.rex` encodes one dev10 temporal pattern once, adapts it once, then renders the same `MLGraph` as native 3-D, top-down shape, X/time, and Y/time. Each graph point still retains its originating `MLCylindricalTemporalPoint`; the views are presentation-only projections.

## Dependencies

Reference SVG renderer:

- ooRexx 5.3.0 (qualified with r13196)
- ooRexx `rxmath`

ML adapter qualification:

- ooRexx ML v0.1-dev11 (pattern, temporal-pattern and wobbly-fit contracts)

Optional matplotlib renderer:

- ooRexx Foreign Runtime v0.22.6
- Python with matplotlib (qualification: Python 3.13.5, matplotlib 3.10.8, NumPy 2.3.5)

No Python/native handle is stored in `MLGraph`, graph series, graph points, or ML learned state.
