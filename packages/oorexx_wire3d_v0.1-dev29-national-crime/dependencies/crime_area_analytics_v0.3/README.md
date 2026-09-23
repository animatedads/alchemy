# Crime Area Analytics v0.3

API family: `crime.area.analytics/0.3`

Renderer-neutral public-crime data model, ingestion, normalization, temporal analysis and spatial-context projection for the UK crime-map work.

The target consumer is the same semantic application rendered as the 3D UK map, Web, Swing, GTK, Android, Windows or another renderer.  No map styling or scene behaviour lives in this package.

## v0.3

v0.3 turns the v0.2 count/change map into a practical national semantic data service.

### Explicit normalized metrics

The map now distinguishes the underlying metric from the time comparison:

```text
metricKind
  COUNT
  RATE_PER_1000
  DENSITY_PER_KM2

comparisonKind
  VALUE
  ABSOLUTE_CHANGE
  PERCENT_CHANGE
```

`RATE_PER_1000` requires an evidence-bearing `POPULATION` denominator.
`DENSITY_PER_KM2` requires an evidence-bearing `AREA_KM2` denominator.
Missing denominators produce an unavailable value with a reason; they are never guessed.

`CrimeAreaDenominatorSet` supports period-effective denominator values and source provenance.  CSV import/export is through the ooRexx distribution `CsvStream` class only.

### Temporal pattern evidence

`CrimeTemporalPatternAnalyzer` adds a second temporal view above the existing linear trend assessment:

- current/previous change;
- rolling baseline mean and standard deviation;
- baseline z-score;
- consecutive non-zero activity;
- recent versus prior slope;
- acceleration/deceleration evidence;
- evidence grades from one-point through seasonal-window history.

It remains descriptive.  A temporal signal is not an inference about an offender or enterprise.

### GIS-neighbour context

`CrimeAreaNeighbourGraph` continues to consume topology supplied by NoSQLServer GIS rather than calculating polygon topology itself.

v0.3 adds:

- CsvStream-backed neighbour-relation import;
- comparison with immediately adjacent areas;
- connected hotspot clusters;
- normalized-metric spatial lag analysis.

An animated map line or contiguous hotspot surface therefore has explicit statistical/topological semantics underneath it.

### National-map compact projection

A country-wide 3D frame should not instantiate a large secondary object graph merely so a renderer can shade 35,672 polygons.

`CrimeMapSemanticService` now has two semantic projection forms:

```text
FULL
  CrimeMapAreaFact[]
  rich hotspot/trend/temporal/neighbour assessment objects

COMPACT
  CrimeMapCompactAreaLayer
  columnar arrays aligned by LSOA code
  metric/count/change/hotspot/evidence scalars
```

`assessmentDetail=AUTO` selects FULL for scoped/small requests and COMPACT above the configured threshold (5,000 areas by default).

Snapshot category shards are also sparse in v0.3.  The writer discovers the category set once, opens one ooRexx `CsvStream` per category, and routes each existing non-zero frame/category cell exactly once.  It no longer scans the complete LSOA universe separately for every crime category.

This is not a renderer shortcut: `CrimeMapCompactAreaLayer` is still a semantic data object.  It contains no colours, materials, meshes, extrusion heights, camera state or animation instructions.

The intended UI pattern is:

1. country / region view requests a compact frame;
2. time slider and crime filters replace that frame;
3. hover can use compact values immediately;
4. selection/zoom scopes `areaCodes` and requests FULL detail;
5. the renderer then receives the complete assessment objects for the selected area(s).

## Structured I/O rule

There is no package-local CSV or JSON parser.

CSV syntax is owned by the ooRexx distribution:

```rexx
::requires "csvStream.cls"
```

JSON syntax is owned by:

```rexx
::requires "json.cls"
```

This applies to police source data, derived relations, LSOA references, denominator relations, adjacency relations and filter-catalog JSON.

## Pipeline

```text
data.police.uk CSV
       |
       | ooRexx CsvStream
       v
CrimeAreaAggregateBuilder
       |
       v
CrimeAreaDataset
       |
       +------ denominator relation ------> CrimeMetricCalculator
       |
       +------ GIS neighbour relation ----> CrimeSpatialAnalysis
       |
       v
CrimeMapSemanticService
       |
       +--> FULL CrimeMapAreaFact objects
       |
       `--> COMPACT CrimeMapCompactAreaLayer
                    |
                    v
           3D / Web / Swing / GTK / Android / Windows renderer
```

LSOA polygon truth remains NoSQLServer/GIS authority.  This package carries `geometryRef` and GIS-derived neighbour evidence; it does not parse GeoJSON polygons or calculate topology.

## Core modules

- `src/CrimeAreaModel.cls` — source observations, area/time frames, rich map facts, compact area layer and evidence bridge.
- `src/CrimeFilterModel.cls` — shared renderer-neutral filters and ooRexx JSON filter-catalog loading.
- `src/CrimePoliceData.cls` — CsvStream source ingestion, aggregation and snapshot relations.
- `src/CrimeMetricModel.cls` — population/area denominators and COUNT/RATE/DENSITY calculation.
- `src/CrimeTrendAnalysis.cls` — trend, hotspot distribution and lagged-correlation primitives.
- `src/CrimeTemporalAnalysis.cls` — recent-baseline and temporal-pattern assessment.
- `src/CrimeSpatialAnalysis.cls` — GIS-neighbour graph, local context, hotspot clusters and spatial association.
- `src/CrimeMapSemanticService.cls` — FULL/COMPACT map-frame projection.

## Supplied police archive profile

The supplied export contains `2025-08` and `2025-09` partitions.

| Layer | Rows |
| --- | ---: |
| street crime | 1,001,088 |
| outcomes | 833,821 |
| stop/search | 84,970 |

The street-crime source contains 14 published crime categories.

## Semantic locks

- stop/search remains a distinct observation layer and is never counted as recorded crime;
- police street coordinates remain `PUBLISHED_ANONYMISED`;
- police-published LSOA assignment remains source evidence;
- count, population rate and spatial density are different metrics;
- percent change from a zero baseline is explicitly undefined (`NEW_FROM_ZERO`), not infinity;
- hotspot comparisons retain metric and peer-population context;
- short history remains evidence-graded rather than promoted to a strong trend;
- neighbour comparison and lagged correlation do not assert offender movement or causation;
- public area statistics never attach automatically to `CriminalEnterprise`, `Person`, `Incident` or another investigation object;
- geometry/topology belongs to NoSQLServer GIS;
- renderer styling and scene state remain outside the crime model.

## Qualification

All v0.2.1 structured-I/O/ingest/model regression tests continue to pass under the supplied ooRexx 5.3.0 r13196 debug runtime.

New v0.3 tests cover:

- denominator CsvStream round-trip including quoted source evidence;
- population-normalized rate;
- physical density;
- percent change;
- missing-denominator fail-closed semantics;
- six-period trend/temporal analysis;
- GIS-neighbour CSV import;
- local-neighbour context;
- connected hotspot clusters;
- compact map projection.

An actual-source probe ingested both supplied City of London monthly partitions with 35,672 seeded LSOA identities:

```text
street rows      1,477
outcome rows     1,450
stop/search rows   473
populated frames    62
```

The same in-memory dataset produced a 35,672-LSOA COMPACT change frame in about 11.8 seconds on the supplied debug runtime in the qualification container.  This is runtime evidence, not a cross-machine performance guarantee.

See `VALIDATION.txt` and `docs/` for the contracts.
