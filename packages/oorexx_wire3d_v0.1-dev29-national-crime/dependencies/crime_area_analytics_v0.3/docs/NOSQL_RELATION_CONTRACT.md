# NoSQL relation contract for crime-area analytics v0.3

NoSQLServer is the persistence/query/GIS authority below this package.

Suggested relation families:

```text
police_street_crime
police_outcome
police_stop_search
lsoa_2021
lsoa_2021_geometry
lsoa_2021_neighbour
crime_area_denominator
crime_area_period
crime_area_category_period
crime_trend_assessment
crime_temporal_assessment
crime_hotspot_assessment
crime_hotspot_cluster
crime_spatial_lag_assessment
```

Source relations preserve public evidence.  Analytical relations are reproducible derivatives and retain method/source revision.

## Street crime

```text
crime_id
month
reported_by
falls_within
longitude
latitude
location
lsoa_code
lsoa_name
crime_type
last_outcome_category
context
source_batch_id
source_file
source_row
```

GIS may project:

```sql
ST_POINT(longitude, latitude, 4326)
```

without overwriting the source coordinates.

## Area-period aggregate

Key:

```text
(area_type, area_code, period_key)
```

Core values:

```text
total_crime_count
with_point_count
without_point_count
with_crime_id_count
```

Crime-category and outcome dimensions remain separate derived relations/shards as appropriate.

## Denominator relation

Normalization is impossible without explicit denominator evidence.

```text
lsoa_code
denominator_kind        POPULATION / AREA_KM2
value
unit
effective_from_period
effective_to_period
source_ref
source_revision
method
```

Population data should come from its authoritative demographic source.  Physical area should come from the GIS layer using an appropriate CRS/measurement contract, not from hand geometry in the crime package.

## Neighbour relation

Polygon topology is computed by NoSQLServer GIS and consumed by crime analytics:

```text
area_a
area_b
relation_type           TOUCHES initially
evidence_ref
source_revision
```

The relation is undirected for the present LSOA adjacency model.  The crime package canonicalises the edge while preserving GIS evidence.

## Map projection

`CrimeMapCompactAreaLayer` is an application object rather than a mandatory persisted relation.  If materialised for caching, preserve at least:

```text
request/filter fingerprint
source revision
period
baseline period
metric kind
comparison kind
metric unit
peer set
ordered area code
metric availability/value
raw/baseline counts
hotspot band/percentile/z-score
evidence ref
```

Renderer-specific fields must not enter that relation.
