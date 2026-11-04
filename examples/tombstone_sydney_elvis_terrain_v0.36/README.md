# Sydney Harbour ELVIS terrain provider — v0.36 handoff

Architect: Tom Dyer. User-supplied height words and original DEM translation: Claude (Opus 5.5) / SLAM Draw / Top Rope SLAM, 2026-11-02. Read-only native ooRexx adapter and qualification: ChatGPT GPT-6, 2026-11-02.

## Real source provenance

The user uploaded `harbour_heights.words` and its complete raw bytes were verified, SHA-256 `3243f644556f084bf8f524b6b080f8b539fdf5986622b4b207a3a690c32a102e`. It declares a Sydney Harbour height map derived from NSW Spatial Services `Sydney-DEM-AHD_56_5m.asc`, GDA94 MGA Zone 56, vertical AHD71 and reported ±0.9m 95% vertical error. The upstream ASC and `mga.cls` were **not** supplied or verified: only the derived 50-metre words are independently qualified here.

Actual ASCII grid: 226 columns x 204 rows = **46,104 source cells**, 45,165 numeric and 939 literal NoData `-`. Range **−14.5..108.3m**, top-left sample centre E330586.9,N6259261.5 and bottom-right sample centre E341836.9,N6249111.5; 50-metre spacing. A declared six-place metadata block is not a substitute for sampling. Example source cell near Observatory Hill: 41.0m versus source place annotation 41.6m; Fort Denison sample 2.5m vs metadata 2.4m; Harbour Bridge sample 0.1m vs metadata 0.2m. The grid cannot establish bridge deck clearance or a survey-grade coast boundary.

## Native read-only adapter (delivered reproducibly)

`HarbourHeightWords.cls` implements `queryXY(MGA56_E, MGA56_N [, externalMapWaterPositive])` returning original height word or NoData/outside status plus explicit GDA94/MGA56 and AHD71, cell row/column, method NEAREST_GRID_WORD, bare-ground only, zero vertical exaggeration, water UNKNOWN or a **low-elevation candidate**. If caller supplies positive-water evidence it is labelled as external/unvalidated; this module cannot authenticate map-water. It does not infer LAND from any non-water bitmap. No latitude/longitude conversion is invented here without the original `mga.cls` source.

Native ooRexx 5.3.0 r13196 **executed 29/29** semantic/provider tests, **120/120** deterministic exact cell samples including **20/20 NoData**, and **12/12** deliberately corrupted word-file structures rejected. File SHA independently checked by fail-closed shell runner. No OpenCV or Python vision, no code-path TESTED promotion. Development-only Python/PROJ sanity-check of approximate landmark MGA metres was separate and not part of native runtime.

The complete user-delivered reproduction archive `sydney_harbour_elvis_terrain_v0.36.zip`, SHA256 `eedd935b8e03e21854ea5b98581bf8cbc3329a52a28176e14551164f0be19056`, contains the unchanged original `.words`, native class/CLI/tests, 120-point fixture, negative suite, execution log and all-file SHA256SUMS. **Original words are not published in GitHub until distribution/attribution permissions are confirmed; the conversation archive is the source reference.**

## Integration required

Canonical `power-slam-harbour` owner retains above-ground bridge/pylon/Cahill/Opera House/wharf geometry and `SlamHarbourOcclusion.cls` ray/solid tests. DEM is *bare ground*: bridge 0.1m describes underlay not roadway. Fort Denison's height 2.5m is not dry land proof; water may override only with positively supported source-layer evidence. SLAM Draw x4 vertical exaggeration is graphical, not metric. V5V camera frames remain pixel-space observations until real lens pose and scene projection are qualified. Geographic ferry identity/locations are still BLOCKED_UNCALIBRATED and all input evidence OBSERVED_UNTESTED.

Geometry-owner interface review was opened in Rasen Falcon as REQ-00003019; this source-backed qualification is the follow-up. No canonical Power SLAM or SLAM Store merge asserted.
