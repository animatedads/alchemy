# dev27 — generic Wire presentation objects

Wire3D is a renderer, not the UI model. dev27 introduces `WirePresentation.cls`, a renderer-neutral presentation vocabulary shared by Android, Web, Swing and Wire3D.

Core objects: `WirePresentation`, `WirePresentationElement`, `WireGeometryMap`, `WireGraph`, `WireTimeGraph`, `WireObjectDetails`, `WireFilterPanel`, `WireDataFeed`, `WireDataSeries`, `WireSelector`, `WireObjectSelector`, `WireRangeSelector`, and `WireTimeSelector`.

Selectors are shared semantic state. A map and graph can bind the same object/time selectors. Selecting an area through the map therefore changes the same selection observed by details and graphs; activating a period through a graph changes the same time selection observed by a map. Renderers choose controls and layout.

The supplied Crime Area Analytics v0.1 package is included unchanged as a qualification consumer. Its `CrimeMapFrame` and `CrimeTrendSeries` are wrapped by generic `WireDataFeed`/`WireDataSeries`; no crime concepts were added to the presentation toolkit.

`tests/test_generic_presentation.rex` is qualified with ooRexx 5.3.0 r13196 and verifies object identity through shared area/time selectors.
