# Wire3D dev29.6 — selectable ward qualification geography

Adds the four user-supplied UK ward TopoJSON datasets as a normalized, explicitly historic/qualification-only WARD presentation layer.

- 9,348 ward features across England, Wales, Scotland and Northern Ireland.
- Source TopoJSON is retained verbatim under dependencies/ward_geography_fixtures.
- Browser receives a normalized CRS84 GeoJSON projection for rendering/search only.
- Wales retains Welsh alternate names where supplied.
- Ward selection frames the boundary but does not fabricate ward-level crime statistics: LSOA crime remains the underlying observation surface.
- BUA, WARD and LSOA identities coexist in geography search.
- Explicit ooRexx HTTP routes added for national demo resources, including ward geography.

The ward source is intentionally labelled HISTORIC WARDS / qualification geography. It is not treated as current electoral authority. Future Civic integration should own normalized civic identity/source evidence, with NoSQLServer GIS owning spatial relationships and Wire owning projection.
