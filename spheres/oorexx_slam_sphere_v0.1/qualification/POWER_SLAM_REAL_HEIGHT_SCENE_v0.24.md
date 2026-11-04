# Power SLAM v0.24 — real Sydney heights / scene-coordinate integration

Architecture: Tom Dyer. ooRexx code: ChatGPT GPT-6. GDA94 MGA56 Transverse Mercator routine: Claude (Opus 5.5), supplied as part of the user's \`slam_heights.zip\` on 2026-11-02.

## Data source and qualification
- Input \`harbour_heights.words\` from the user is external to GitHub, SHA-256 \`3243f644556f084bf8f524b6b080f8b539fdf5986622b4b207a3a690c32a102e\`.
- The 226x204 grid at 50 m was built from NSW Spatial Services 5 m DEM; it is a resampled bare-ground layer, not 5 m terrain detail or a building-height DSM.
- Horizontal coordinate system: GDA94/MGA zone 56, easting/northing metres; vertical datum source AHD71; the user-supplied source quoted ±0.9 m 95% vertical uncertainty.
- \`SlamHarbourMGA.cls\` reproduces Claude's native Transverse Mercator code, requiring ooRexx \`rxmath\`.

## API and fail-closed controls
- \`HarbourWordsMGA~sampleMGA(E,N)\` preserves the original elevation independently of land/water role, returning explicit \`UNKNOWN_OUTSIDE_GRID\` and \`UNKNOWN_NODATA\`.
- v0.24 appends \`COLUMN\`/\`ROW\` indices for covered cells.
- \`HarbourWordsSceneTile~sceneMGA(x,y)\` uses the inverse of the existing HarbourScene approximate local latitude/longitude conversion, then Claude's GDA94 MGA projection; its result is explicitly \`APPROX_TANGENT_TO_GDA94_MGA56\` and \`NOT_SURVEYED\`. The scene's local coordinates cannot be silently called surveyed MGA coordinates.
- \`HarbourWordsSceneTile~sample(x,y)\` implements the sampling/metadata methods required by the existing terrain visibility interface. AHD71 is exposed as an explicitly labelled AHD realisation; no separate structural elevation datum is yet qualified.
- \`HarbourWordsRoleEvidence\` supplies optional, independently sourced classification by grid row/column as L/W/X, along with provenance. Unclassified cells return \`UNKNOWN_UNCLASSIFIED_ROLE\` **even when the numeric height is present**. A bare elevation around 0 m is NOT automatically water.
- These tests use only a synthetic test mask (\`SYNTHETIC_TEST_MASK_ONLY\`). No complete qualified water/coastline layer is claimed.

## Native execution
- Runtime: user's ooRexx 5.3.0 r13196 test package.
- \`test_words_adapter.rex\`: 15/15 PASS with the real height words.
- \`test_words_scene.rex\`: 47/47 PASS with the same real height words. Includes source projection, datum metadata, role conflict handling, missing-data propagation and six Harbour spot checks.
- Source sample readings on the 50 m grid: Goat Island 18.4 m, Fort Denison 2.5 m, Bradleys Head Light 1.3 m, Opera House 3.5 m, Harbour Bridge 0.1 m (water underneath), Observatory Hill 41.0 m. The previously quoted 41.6 m Observatory Hill value was from another-resolution sample; it was NOT forced into this grid.
- The source input file itself is omitted from GitHub and tests require its path as an argument.

## Exclusions and next qualification
- Neither the approximate scene coordinate transformation nor the camera rooftop height and existing bridge/berm solid heights are surveyed AHD scene geometry.
- The 50 m DEM cannot exclude unsampled narrow ridges or qualify precise shoreline geometry.
- Do not yet admit real camera poses, visible/clear real rays or ferry world-coordinate estimates. An independently georegistered full harbour water mask and vertical datum alignment of structures are required before combined terrain/structures tracer qualification.
- Next: consume Claude Top Rope's final \`read_map.rex\` water geometry only after registration and source qualification, then run combined terrain+solid ray tests.
