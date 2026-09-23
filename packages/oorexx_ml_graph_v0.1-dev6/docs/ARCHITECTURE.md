# Architecture

## Meaning remains upstream

`MLGraph` is a semantic scene: coordinate system, ordered axes, series, point coordinates, declared grid/geometry and retained source evidence. Renderers own pixels and projections, not ML meaning.

## Raster/image overlay authority (dev6)

`MLImageScene` is a sibling to `MLGraph`, not a disguised Cartesian graph.  Its base `MLImageSource` is immutable evidence and its `MLImageLayer` objects contain presentation primitives only.  A primitive may retain an upstream evidence object, but it does not gain authority to alter that object.

The normal Vision path is:

```text
V5V wire / Vision processing
        |  (Vision owns decode, palette and temporal meaning)
        v
VisionSurface
        |
        v
MLVisionSurfaceImageSource
        |
        v
MLImageScene + overlay layers
        |
        +--> SVG reference output
        `--> Foreign Runtime / Pillow output
```

The adapter reads `VisionSurface~width`, `~height`, `~at(x,y)`, `~valueCount` and `~valueModel`.  When `valueModel` publishes `colour(index)`, that RGB value is used for presentation.  Otherwise the indexed value is mapped to deterministic greyscale.  The adapter never creates a replacement `VisionSurface`, changes packed values, changes the palette, or assigns new Vision provenance.

V5V frame size is intentionally unconstrained here: the source dimensions are whatever positive dimensions Vision publishes.  Current 55x73, 47x84 and similar experiments therefore require no special case.

### Overlay coordinates and opacity

`PIXEL` coordinates use the Vision/image convention: origin at the top-left, +x right, +y down.  `NORMALIZED` coordinates map 0..1 onto the current source width/height and are presentation coordinates only.  Render scale changes output size while preserving the semantic coordinate system.

Opacity is explicit at three independent levels: colour alpha, style opacity, and layer opacity.  Renderers multiply those values for each primitive.  This is intentionally not a mutation of base pixels.

### High-resolution evidence remains Vision-owned

`VisionHighResolutionRequest` / `VisionRegionMaterial` remain a separate escalation path.  A later image-source adapter may place such material using its published transform/region, but dev6 does not silently substitute high-resolution pixels for the V5V observation.

### Provider boundary

The deterministic SVG renderer is the reference implementation.  It emits the base indexed raster using horizontal run-length rectangles and places vector primitives above it.  The optional Pillow renderer uses Foreign Runtime resident Python objects to create PNG output.  Neither provider handle is stored in `MLImageScene`, and renderer output is not fed back as Vision authority.

## Polar pattern hashing

`MLPatternGraphAdapter` consumes `MLPatternHash~polarPoints` and does not renormalize raw source values.

## Cylindrical temporal pattern hashing

`MLTemporalPatternGraphAdapter` consumes `MLTemporalPatternHash~points`. The originating temporal schema remains authoritative for:

- event resampling;
- angular progress;
- per-channel minimum/maximum normalization;
- time shift/scale policy;
- x/y cylindrical coordinates;
- height/time coordinates;
- bearing/elevation/turn evidence;
- pattern difference.

The graph layer merely maps the already-published point coordinates into a 3-D Cartesian graph whose axis roles are `CYLINDER_X`, `CYLINDER_Y`, `TIME`.

Time is therefore explicit evidence, never array order manufactured by a renderer.

## 3-D reference rendering

The SVG reference renderer supports 3-D Cartesian graphs using a deterministic isometric-like projection. View bounds and projection are presentation operations only. If graph metadata declares `geometry=CYLINDER`, the renderer draws an explanatory cylinder guide. It does not project raw ML values into cylindrical coordinates itself.


## Difference evidence and annotation authority

`MLGraphAnnotation` is graph semantic state, not renderer state. In dev3 the only supported annotation kind is `SUMMARY`; it retains the exact upstream evidence object and is explicitly non-locatable.

`MLGraphDifferenceAdapter` consumes only fields already published by ooRexx ML difference objects:

- pattern: dominant delta, radial maximum, slope maximum, curvature maximum;
- temporal: dominant delta/kind/channel plus radius/time/bearing/elevation/turn maxima.

ooRexx ML v0.1-dev10 does not publish the point or segment index responsible for the dominant delta. Graph therefore writes `difference.location=UNPUBLISHED` and does not scan hash internals to infer one. A future upstream locatable evidence object can be rendered when ML explicitly publishes that authority.

This is a deliberate fail-closed boundary: explanatory graphics may display an upstream conclusion, but may not manufacture a more specific conclusion than upstream evidence supports.


## Contextual wobble and fit-restoration authority (dev5)

`MLWobbleGraphAdapter` consumes ooRexx ML v0.1-dev11 objects after `MLWobbleSetSearch` has completed. Graph is not allowed to call the scorer, search combinations, decide that an observation is an outlier, or turn diagnostic exclusion into deletion authority.

The adapter may perform only presentation mappings justified by published evidence:

- observation `x`/`y` values become graph point coordinates while the original observation Directory remains point evidence;
- membership of the *selected* restoring set comes from `MLWobbleSet~indexes`;
- baseline/restored fit lines are emitted only when the corresponding `MLFitAssessment~evidence` publishes `slope` and `intercept`; evaluating that published line at viewport endpoints is presentation geometry, not a new fit;
- distance-to-fit, normalized distance, evaluation count, normative classification and percentile are read from the exact `MLWobbleAnalysis`;
- participation points are copied from `MLWobbleParticipation`;
- later disposition is attached only from explicit `MLWobbleReassignment` objects.

The graph records `wobble.exclusionAuthority=DIAGNOSTIC_ONLY`. A restoring-set point therefore means only “temporary exclusion belongs to this minimal set for the active model.” It does **not** mean false, noise, clutter, deletion candidate, or globally irrelevant.

When dev11 publishes multiple equally minimal restoring sets, Graph accepts a caller-selected set index for inspection and exposes the total set count. It does not rank those sets. The separate participation graph is the correct place to visualize how often each observation participates across all minimal explanations.

### Point sets are not paths

Dev5 introduces `MLGraphSeries~connection` (`PATH` or `POINTS`). `PATH` is the compatibility default. Wobble observations use `POINTS`, so renderers cannot imply temporal/spatial adjacency merely from Array order. Published model fits remain `PATH` series.

This distinction is generic and useful outside wobble diagnostics whenever the semantic object is a sample set rather than a trajectory.

## Provider boundary

Optional matplotlib remains behind Foreign Runtime. No Python proxy/handle becomes part of graph semantic state or learned ML state.

## Explicit views and projection authority (dev4)

`MLGraphView` is presentation semantic state. It does not contain transformed samples. It identifies either the native graph or an ordered pair of existing graph-axis indexes.

For cylindrical temporal graphs the named view aliases are:

- `SHAPE` / `TOP` -> `CYLINDER_X`, `CYLINDER_Y`;
- `TIME_X` / `SIDE_X` -> `CYLINDER_X`, `TIME`;
- `TIME_Y` / `SIDE_Y` -> `CYLINDER_Y`, `TIME`.

Generic 3-D Cartesian graphs may use `XY`, `XZ`, or `YZ`.

The renderer is allowed to scale those selected coordinates to the viewport because that is presentation. It is not allowed to create new ML coordinates or resample the series. `SHAPE` has `aspect=EQUAL`; this is necessary to preserve spatial geometry, so a circular relation cannot be presented as an ellipse merely because the output rectangle is wider than it is tall. The reference SVG renderer uses a square presentation box and equal coordinate bounds for this view. The matplotlib provider applies the corresponding equal-aspect view.

A graph point's evidence object and coordinate directory are unchanged by selecting or rendering a view. Thus one temporal hash can be examined from several projections without creating several competing semantic scenes.

`MLGraphSeries~semanticKey` remains a presentation-identity hint, not an ML category. Both SVG and matplotlib use it to keep the same channel visually stable across overlay series; role controls line style independently.
