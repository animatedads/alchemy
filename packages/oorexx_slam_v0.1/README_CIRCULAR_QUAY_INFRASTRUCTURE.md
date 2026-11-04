# Power SLAM v0.6 — north shore, Circular Quay station and Cahill Expressway

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 1 November 2026. **Geometry-only qualification, not a real-camera location certificate.**

## User-provided horizontal inputs

- Northern-shore candidate: **-33.848849, 151.213921**, camera at **50 m ASL**. Older Kirribilli House comparison remains. The landmask, building sightline and exact mounting location are unqualified.
- Circular Quay railway platform west end **-33.86146, 151.20980**, east end **-33.86127, 151.21160**. Approximately **167.7 m** great-circle tangent distance, or **167.48 m** in the existing Power SLAM local coordinate conversion. Both agree with 165–170 m.
- Café Sydney camera at **25 m ASL** is the new user estimate, replacing the earlier 50 m assumption; the existing approximate Customs House centre XY is not a surveyed terrace optical centre.

## Additional 3D geometry

Two new cuboids increase the existing 25 to **27**:

| ID | Coordinates | Model vertical envelope | Survey status |
|---|---|---|---|
| CQ_STATION | User's two platform endpoints | 4–12.5 m ASL | 18 m width and height are trial hypotheses |
| CAHILL | Same station-length alignment | 13.5–16.5 m ASL | 17 m width and height are trial hypotheses |

The real expressway extends beyond the station endpoints; this cuboid is only the station-length segment. The 3.8 m quoted underpass clearance is not a height above sea level. A separately documented RL8.35 track reference concerns the eastern approach, not the station's entire longitudinal track level.

The model metadata preserves source provenance and surveyed/not-surveyed flags. The Café Sydney and legacy CIRCULAR camera IDs now render at 25 m in the additive HarbourQuayInfrastructurePanorama subclass. NORTH_SHORE, BLUES and KIRRIBILLI remain at 50 m ASL. The 360° renderer labels its actual input camera elevation dynamically.

Calculated station bearings from the approximate Café Sydney camera: western end **307.77°**, eastern end **36.35°**, Cahill top midpoint **351.40°**. They cross the 0°/360° north seam; both ends project below the 25 m camera. Full building occlusion is not implemented.

## Qualification

On uploaded ooRexx **5.3.0 r13196** and rxmath, all four suites passed:

- panorama: **36/36**
- wharves: **145/145**
- northern-shore candidate: **37/37**
- station, road and corrected camera: **40/40**

**Total 258/258 geometry checks PASS**. No photographed-camera-pose qualification is claimed.

To reproduce from the package root, with RXMath and REXX_PATH pointing to src, run the tests under tests/test_harbour_panorama.rex, tests/test_harbour_wharves.rex, tests/test_north_shore.rex and tests/test_quay_infrastructure.rex. To render run bin/render_quay_infrastructure.rex. The accompanying v0.6 ZIP includes the SVG/PNG 360° model panoramas, a 120° view and SHA-256 manifest.

## Source and unresolved constraints

- NSW Planning Portal 2025 viaduct assessment: https://apps.planningportal.nsw.gov.au/prweb/PRRestService/DocMgmt/v1/PublicDocuments/DATA-WORKATTACH-FILE%20PEC-DPE-EP-WORK%20PAN-536078%2120250515T031902.219%20GMT
- City of Sydney Customs House: https://www.cityofsydney.nsw.gov.au/landmarks/customs-house
- Sydney Tourism Café Sydney fifth floor: https://www.sydney.com/destinations/sydney/sydney-city/city-centre/food-and-drink/cafe-sydney
- Transport NSW interchange map: https://transportnsw.info/sites/default/files/document/2018/02/circular_quay_station_map.pdf

Required before a real pose can be certified: surveyed terrace optical centre and vertical datum; GIS shoreline mask; station and expressway actual elevations; photographic pixel measurements and 3D occlusion tests.
