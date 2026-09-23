# Crime Map Semantic Contract v0.3

The eventual 3D UK map renders crime semantics; it does not become a second crime-analysis implementation.

## 1. Scale changes projection shape, not truth

At country scale the application may have all 35,672 LSOAs in one frame.  Building a deep object graph for every polygon is wasteful, so v0.3 defines two equivalent semantic projections.

### COMPACT wide-area projection

`CrimeMapCompactAreaLayer` is columnar and aligned by `areaCodes[]`.

It carries, per area:

```text
geometryRef
metricValue / availability / reason
observationCount
baselineObservationCount
currentMetricValue
baselineMetricValue
comparisonState
hotspotBand
hotspotPercentile
hotspotZScore
evidenceRef
```

It contains no render instructions.

### FULL scoped projection

`CrimeMapAreaFact` carries the same core facts plus rich assessment objects:

```text
CrimeHotspotAssessment
CrimeTrendAssessment
CrimeTemporalPatternAssessment
CrimeNeighbourContextAssessment
```

A renderer should normally use COMPACT for country/region display and issue a scoped FULL request when a user selects or drills into one or a manageable set of areas.

## 2. Metric and comparison are orthogonal

The UI must not mix normalization and time comparison into one ambiguous selector.

Metric:

```text
COUNT
RATE_PER_1000
DENSITY_PER_KM2
```

Comparison:

```text
VALUE
ABSOLUTE_CHANGE
PERCENT_CHANGE
```

A hotspot computed from raw counts is a different analytical fact from a hotspot computed from population-normalized rates.

Population rate and spatial density require explicit denominators.  The map must be able to represent unavailable areas rather than inventing a denominator.

## 3. Country-view hotspot semantics

A hotspot is not the colour that depicts it.

Every available area can carry:

```text
metric value
peer set
peer mean / standard deviation
z-score
empirical percentile
intensity band
```

The national renderer may turn those into polygon material, height, glow, particles or another representation.  Those choices do not change the hotspot result.

v0.3 computes real-valued rate/density percentile ordering through a native-sort-friendly fixed-width numeric key.  Visible metric values and z-scores remain unquantized; percentile ordering uses 1e-6 resolution for non-integer metrics.

## 4. Time slider

The period is an authoritative query dimension.  Moving the UI time slider requests a different semantic frame.

The renderer must not interpolate an invented monthly crime count and present it as source data.

Visual interpolation between two frames is permissible as animation, provided the application still knows the two authoritative source frames being animated between.

## 5. Trend versus recent temporal state

`CrimeTrendAssessment` answers the broad series-direction question and grades the history window.

`CrimeTemporalPatternAssessment` answers a different question: how the newest observation relates to its recent baseline, including:

- previous-period change;
- rolling baseline;
- baseline z-score;
- consecutive activity;
- slope change / acceleration evidence.

The renderer may display both.  Neither is causal evidence.

## 6. Neighbourhood context

NoSQLServer GIS owns polygon topology.  It may publish an adjacency relation derived from LSOA geometry, for example through `ST_TOUCHES`.

The crime package consumes that relation as `CrimeAreaNeighbourGraph`.

`CrimeNeighbourContextAssessment` compares an area's selected metric with the metrics of its adjacent areas.  This permits a UI to distinguish:

- nationally elevated;
- locally elevated relative to surrounding LSOAs;
- part of a wider contiguous hotspot.

Those are distinct facts and should remain distinguishable in presentation.

## 7. Contiguous hotspot clusters

`CrimeHotspotCluster` is a connected component of areas meeting a declared hotspot-band threshold in the GIS-derived neighbour graph.

It carries area membership, metric summary, maximum percentile, threshold and graph revision.

A 3D renderer may therefore show a coherent hotspot surface spanning several LSOAs without merging the underlying area identities or geometries.

## 8. Published point resolution

Street-crime points remain labelled `PUBLISHED_ANONYMISED`.

Zooming into a point must never change that semantic precision.  The visual marker may become larger or more detailed, but it must not imply that the coordinate is the exact offence location.

## 9. Spatial association / apparent movement

`CrimeSpatialLagAssessment` describes lagged statistical association between explicitly related areas.

Its interpretation remains:

> Statistical association only; not offender movement or causation.

A 3D line or animated flow may represent that association.  The animation is not evidence that the same offenders physically travelled along it.

## 10. Investigation boundary

Public-area analytics do not automatically become evidence against a person, organisation or `CriminalEnterprise`.

Crossing into an investigation requires an explicit `CrimeAreaEvidenceBridge` with the relationship and asserting authority recorded.

## 11. Shared filters

The common semantic filter set includes:

```text
dataLayer
period
crimeType
lastOutcome
outcomeType
reportedBy
fallsWithin
lsoa
metric
comparison
trendDirection
temporalPattern
hotspotBand
neighbourContextBand
stopType
stopObject
stopOutcome
stopAge
stopGender
stopOfficerDefinedEthnicity
```

3D, Web, Swing, GTK, Android and Windows projections consume the same ids.

## 12. Renderer exclusions

The domain model never defines:

```text
colour
material
mesh
terrain height
scene node
camera
label placement
icon
animation curve
LOD mesh
```

Those belong to the renderer while stable area identity, geometry reference, metric values, assessments and evidence remain shared semantics.
