# Power SLAM Harbour — wharf geometry qualification v0.4

Date: 2026-11-01. Architecture: Tom Dyer. Implementation/qualification: ChatGPT GPT-6.

Canonical code: `packages/oorexx_slam_v0.1/src/SlamHarbourWharves.cls`; rendering uses `SlamHarbourPanorama.cls` and the previously implemented `SlamHarbourPose.cls`. Detailed source and coordinate ledger: `packages/oorexx_slam_v0.1/README_WHARVES.md`.

- Model: 25 solid cuboids (7 original bridge/Opera/Salesforce; 10 Circular Quay Wharf 2–6 deck/roof; 8 Walsh Bay Pier 2/3, Wharf 4/5, Pier 6/7, Pier 8/9 deck/roof).
- Geometry projection: 360° true-north clockwise panorama, three nominal 50-m-ASL land sites (Kirribilli House, Customs House/Circular Quay, Blues Point); the renderer uses original local tangent-frame model geometry and reports landmark bearings.
- Source trust: CQ2–5 representative points and WB45 point sourced from published references. WB23 is a **nearby monument reference, not a wharf survey**. CQ6, WB67, WB89 are explicit geographic hypotheses. **All** pier dimensions/roof heights/orientations and footprints are estimated. Wharf ledger sets `SURVEYED_FOOTPRINT=.false` and `SURVEYED_ROOF=.false` throughout.
- Qualification (user-supplied ooRexx 5.3.0 r13196, 2026-11-01): **145/145** added wharf tests PASS; **36/36** original panorama regression PASS; 3 rendered SVGs independently parsed, each has 450 cuboid face polygons within the root, and was rasterised into a PNG.
- Land-camera admission is distinct from pier geometry: piers are physically in blue harbour water, but cameras remain restricted to permitted land sites. The virtual altitude does not certify a publicly accessible camera platform.
- **Evidence classification: synthetic geometry consistency only.** This result does **not** measure actual roof corners, qualify photo landmark pixels, solve a real camera position, or validate a georeferenced land-water mask. No claim of real-photo pose recovery is admitted by this qualification.

Next qualification gate: sourced aerial/OSM/cadastral per-vertex pier geometry with uncertainties, corresponding measured image landmarks, independent withheld landmarks and a fail-closed camera fit.
