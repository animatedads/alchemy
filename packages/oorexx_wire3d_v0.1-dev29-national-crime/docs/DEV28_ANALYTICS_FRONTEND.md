# dev28 — Generic analytical presentation frontend

Adds a renderer-neutral analytical frontend proof using generic geometry-map, object-selector, time-selector and time-graph semantics. `web/wire-analytics.js` contains no crime or LSOA domain vocabulary. The supplied Crime Area Analytics v0.1 example is only the qualification consumer.

`web/lsoa-demo.geojson` is a 32-feature subset selected from the supplied December 2021 LSOA boundary GeoJSON around E01000001. Geometry remains Polygon/MultiPolygon source geometry; the browser only projects it to SVG.

`web/analytics.html` uses the Crime Area Analytics example values (Burglary COUNT 10 for 2025-08 and 15 for 2025-09) as an explicitly labelled fixture. Clicking geometry changes the shared object selector; clicking either the time selector or graph point changes the same time selection.

This is intentionally a conventional analytical frontend. Wire3D can project the same semantic objects spatially without making the common presentation contract spatial.
