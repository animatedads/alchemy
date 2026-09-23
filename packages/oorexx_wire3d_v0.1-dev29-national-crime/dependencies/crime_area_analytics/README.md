# Crime Area Analytics v0.1

API family: `crime.area.analytics/0.1`

This package is the renderer-neutral data/model/analysis side of the public UK crime map work.
It is designed to feed the same semantic application into Wire/3D, Web, Swing, GTK, Android or
other renderers.  It does **not** implement the map renderer.

## What is in v0.1

- `src/CrimeAreaModel.cls`
  - source-evidence objects for street crime, crime outcomes and stop/search;
  - LSOA/area and period identities;
  - area/month aggregate frames;
  - trend, hotspot and spatial-lag assessment objects;
  - renderer-neutral `CrimeMapFrame`, `CrimeMapAreaFact` and `CrimeMapPointFact`;
  - an explicit, human/assertion-owned bridge to the existing investigation / criminal-enterprise model.

- `src/CrimeFilterModel.cls`
  - renderer-neutral filter definitions, values, catalogs and selections;
  - base filter dimensions for street crime, outcomes, stop/search and derived map analytics;
  - matching logic for published street-crime observations.

- `src/CrimeTrendAnalysis.cls`
  - mean / standard deviation / linear slope / Pearson primitives;
  - trend assessment with evidence-window grading;
  - peer-set hotspot assessment;
  - lagged spatial association assessment.

- `data/police_uk_filter_catalog_2025-08_2025-09.json`
  - filter values and source counts derived from the supplied police archive.

- `docs/MAP_SEMANTIC_CONTRACT.md`
  - the data contract required by a zoomable 3D UK crime-map projection.

## Source archive observation

The supplied archive named `e4e2ac43a823c2e3e272d4ac8a7257f77f83e5bc.zip` actually contains two
monthly partitions: `2025-08` and `2025-09`.

Combined contents observed during this build:

| Layer | Rows |
| --- | ---: |
| street crime | 1,001,088 |
| outcomes | 833,821 |
| stop/search | 84,970 |

The street-crime taxonomy in this archive contains 14 published categories.
The generated filter catalog preserves the source labels and counts rather than inventing a second taxonomy.

## Architectural boundary

The public-data model is not an extension of `CriminalEnterprise`.

`CriminalEnterprise`, `Person`, `Incident`, `Sighting`, evidence and investigation objects describe
case/evidential semantics. Public police area data is anonymous/statistical source evidence. A trend,
hotspot or lagged spatial association therefore does not automatically become evidence about a named
person or enterprise.

`CrimeAreaEvidenceBridge` exists for an explicit separately-authorised assertion when a real investigation
needs to cite an area-analysis result.

## Map contract

At UK scale the preferred semantic output is area facts keyed by LSOA geometry. At closer zoom the same
query may additionally expose the police-published anonymised points. The data objects never prescribe
colour, extrusion, icon, material, camera or scene-node layout.

A renderer can therefore make the 3D UI radically different while preserving the same application truth.

## Metrics

`COUNT` is immediately available from the police source.

`RATE` requires an explicit population or other denominator with provenance.

`DENSITY` requires an explicit area denominator. It must not be calculated from EPSG:4326 degree-space
polygon area and presented as a physical density; the GIS layer must provide an appropriate physical area
calculation or transformed geometry.

A hotspot always carries the metric and peer set used to calculate it.

## Movement semantics

`CrimeSpatialLagAssessment` means temporal/spatial statistical association only.
It does not mean the same crime, offender or criminal enterprise physically moved between two LSOAs.

## Qualification

Validated with the supplied ooRexx 5.3.0 r13196 internal-test runtime.
See `VALIDATION.txt` and `tests/smoke.rex`.
