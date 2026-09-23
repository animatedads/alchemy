# dev26 — resource resolution + embedded geographic context

* Person headshots are now browser-facing ResourceRefs under `/resource/person/<ref>/headshot`; domain objects do not expose Android filesystem paths.
* The ooRexx HTTP server opens resources before determining remaining byte count and serves the controlled ResourceRef routes as binary `image/png`.
* `Wire3DMapElement` is a renderer-neutral geographic presentation element.
* The investigation card embeds the OSM share/export map as a preview and retains an ENTER MAP semantic/navigation affordance.
* OSM attribution and licence link are visible with the map.
* Geographic presentation does not manufacture a Moment; the source geographic fact remains authoritative.
