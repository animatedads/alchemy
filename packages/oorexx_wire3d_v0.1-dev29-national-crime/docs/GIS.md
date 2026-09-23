# Wire3D GIS adapter contract — dev3

Wire3D does not implement GIS semantics. The existing NoSQLServer GIS/GeoPackage layer remains authoritative for typed geometry, geometry subtype, SRID/CRS identity, GeoPackage payloads, spatial predicates, federation, and `ST_*` semantics.

`Wire3DGeoPlacementAdapter` is the seam between that authority and a spatial renderer. An adapter receives the authoritative geometry/SRID plus coordinates supplied or derived by the GIS side and returns a `Wire3DGeoPlacement`. Wire3D uses only the resulting world position for presentation.

Consequences:

* no latitude/longitude fields are added to every `Wire3DSpatialObject`;
* no CRS database, reprojection engine, `ST_*` predicate, GeoPackage parser, or geometry reinterpretation is introduced here;
* source geometry remains a rich source object/reference rather than being flattened into renderer coordinates;
* SRID is retained as source metadata;
* a renderer coordinate is presentation state and is never asserted to be the authoritative GIS coordinate;
* future PROJ/GDAL/GEOS acceleration belongs below the existing GIS boundary, not in Wire3D;
* geographic and abstract spaces can coexist and nest: a geographic feature may be entered to reveal a non-geographic service/object topology.

The initial `Wire3DProjectedCoordinateAdapter` is deliberately bounded: it accepts world/projected coordinates already selected by the GIS projection policy. It performs no CRS conversion itself.

## Raster / coverage surfaces (dev4)

`Wire3DGeoSurfaceProjection` projects an authoritative raster/DEM/coverage as one semantic dataset. It does not create a spatial object for every raster cell. Renderer meshes, normals and LODs are derived presentation state. `Wire3DEvidenceState` separately records whether represented knowledge is surveyed, observed, reconstructed, inferred or unknown. Sample resolution and evidence confidence are intentionally independent.
