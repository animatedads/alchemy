# NoSQLServer v0.76 spatial SQL

v0.76 adds the first executable spatial SQL surface over the typed geometry
values introduced by the GeoPackage work.

This is deliberately a **narrow, exact** implementation. It is not a claim of
full OGC Simple Features support.

## Supported geometry transport

The spatial kernel consumes `GeoPackageGeometry` / `DatabaseGeometryValue`
objects carrying GeoPackageBinary bytes. It validates:

- GeoPackage `GP` magic and header shape;
- GeoPackage envelope length;
- declared geometry subtype against the embedded WKB type;
- table/metadata SRID against the GeoPackageBinary SRS id when both are known;
- WKB byte order and complete coordinate payload.

The v0.76 decoder supports 2D WKB:

- `POINT`;
- `POLYGON` (outer ring plus zero or more holes).

Unsupported WKB kinds fail explicitly rather than being coerced or approximated.

## SQL functions

Accessors:

```sql
ST_GEOMETRYTYPE(geometry)
ST_SRID(geometry)
ST_X(point_geometry)
ST_Y(point_geometry)
```

Predicates:

```sql
ST_WITHIN(point_geometry, polygon_geometry)
ST_INTERSECTS(point_geometry, polygon_geometry)
ST_INTERSECTS(polygon_geometry, point_geometry)
ST_INTERSECTS(point_geometry, point_geometry)
```

`ST_WITHIN(POINT, POLYGON)` is strict: a point on the polygon boundary is not
within the polygon. `ST_INTERSECTS(POINT, POLYGON)` includes the boundary.
Polygon holes are respected.

Spatial predicates reject incompatible non-zero SRIDs instead of comparing
unlike coordinate systems.

## JOIN integration

Spatial predicates are ordinary SQL value expressions. They therefore use the
same general INNER JOIN predicate machinery introduced in v0.72:

```sql
SELECT a.uprn
FROM sample_address a
JOIN sample_minor p
  ON ST_WITHIN(a.geometry, p.geometry) = TRUE;
```

There is no GeoPackage-specific join planner. With no hashable equality
connector this uses `INNER_PREDICATE_CHAIN`.

## Capabilities

v0.76 advertises the narrow NoSQLServer feature flags:

- `SPATIAL_POINT_POLYGON_FUNCTIONS`
- `ST_WITHIN_POINT_POLYGON`
- `ST_INTERSECTS_POINT_POLYGON`
- `ST_GEOMETRY_ACCESSORS`

The broad Database Core `SPATIALFUNCTIONS` capability is intentionally **not**
advertised yet because the current surface is only POINT/POLYGON.

## Not implemented / not claimed

v0.76 does not implement or claim:

- LINESTRING / MULTI* / GEOMETRYCOLLECTION evaluation;
- Z or M coordinate semantics;
- polygon/polygon topology predicates;
- `ST_DISTANCE`;
- buffering or constructive geometry operations;
- coordinate reprojection;
- geodesic calculations;
- spatial indexes or candidate-envelope pushdown;
- automatic repair of invalid geometry.

The principle remains: a spatial operator is advertised only when its actual
geometry semantics are implemented and tested.
