# v0.1-dev3

Adds the first explicit GIS compatibility seam without making Wire3D a GIS engine.

* `Wire3DGeoPlacement` preserves source geometry identity, SRID, and renderer/world placement separately.
* `Wire3DGeoPlacementAdapter` is the OO adapter protocol.
* `Wire3DProjectedCoordinateAdapter` accepts coordinates already selected by authoritative GIS projection policy; it does not transform CRS.
* `Wire3DGeoObjectProjection` projects an authoritative GIS feature while marking GIS authority as `SOURCE`.
* GIS regression assertions ensure geometry identity and SRID survive projection.

The architectural owner of GeoPackage parsing, typed geometry and spatial semantics remains the existing NoSQLServer GIS layer. Database Core remains GIS-agnostic. Wire3D only visualises the result.
