# Wire3D dev29.5 — mixed geography experiment

This development handoff makes the supplied ONS Built-up Areas 2024 England & Wales geography a peer contextual layer over the LSOA crime map.

- 7,775 BUA 2024 identities are searchable alongside LSOA 2021 identities.
- BUILT-UP AREAS toggles settlement boundaries without changing the underlying LSOA crime statistic.
- Selecting a BUA frames the settlement and labels it as context; it does not invent a BUA crime aggregate.
- Geography CLEAR restores ALL geographies and the national camera extent. HOME remains camera-only.
- Crime CLEAR restores ALL CRIME.
- Corrected north/south framing sign and added an algebraic regression proving a framed feature centre maps to the canvas centre.
- Corrected the dev29.4 Promise.all defect: stop-search.json is now fetched explicitly and empty stop/search data is safe.
- The supplied BUA source was renderer-LOD simplified with topology preservation. Identity and geometryRef are retained. Source SHA-256: 62c00c8f4197ebf51d16483a44fe09efad2315ecd3e10f7fe06cddb8df40f076. Derived layer SHA-256: 11a5fb4b3617020e3d8450befdba4ab59c919ada77741458dd69fcfe14b18a36.

## Deliberate boundary

The current national crime frame contains only all-crime Aug/Sep counts. Category selection is therefore not yet used to recolour or relabel counts: doing so would fabricate category-specific statistics. The Crime Area Analytics dependency already defines category COMPACT frames; the next data build must publish those real national category shards into the browser frame. Until then the UI retains category intent only.
