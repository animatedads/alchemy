# Power SLAM Harbour v0.13 — pylon image correspondence qualification

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 2026-11-01.
Rasen Falcon lane: `power-slam-harbour`; ferry recognition owner: `tombstone-vision`.

## Defect fixed
Earlier Café Sydney photo controls `S_TOP`, `N_TOP`, `S_DECK`, `N_DECK` were based on artificial **midpoints between two physical stone towers**, not guaranteed to coincide with the individual visible rooftop towers. In v0.13, `SlamHarbourPinCorrespondence.cls` uses individually user-pinned ROOF-INTERIOR features and enumerates all four plausible south × north pylon assignments. It forbids direct midpoint-as-photographed-tower lookups, retains unsurveyed semantics, checks independent arch-crown projection and camera roof search boundary, and refuses admission of all current photographic poses.

## Photo diagnostic — 1536x862 Café Sydney image
OoRexx pinhole fitter rerun with direct roof-pin/deck-proxy IDs (the pixel points themselves are provisional):

| Visible tower hypothesis | training chi² | camera height (m ASL) | horizontal FOV | held-out arch error (pixels) | bound | status |
|---|---:|---:|---:|---:|---|---|
| SW/NW | 0.257 | 45.17 | 34.82° | 109.5 | reached | BLOCKED |
| SW/NE | 0.424 | 42.75 | 37.44° | 75.2 | reached | BLOCKED |
| SE/NE | 0.588 | 42.81 | 34.15° | 34.9 | no | BLOCKED |
| SE/NW | 2.553 | 47.50 | 31.38° | 77.4 | reached | BLOCKED |

Different correspondence assignments produce materially different apparent height/FOV without independent validation. Unqualified scene geometry, arch crown model, approximate deck proxies, and a provisional 80m × 64m polygon mean the camera remains UNKNOWN; these are diagnostic candidate fits only. No boat geographic position/speed can be published as calibrated from them.

## Native qualification
Combined local ooRexx 5.3.0 r13196, rxmath, nine tests all exit 0:
- bridge audit 19
- structural semantics 27
- roof pins 29
- camera footprint synthetic 24
- panorama 36
- wharves 145
- north shore 37
- Circular Quay infrastructure 40
- new pin-correspondence fail-closed suite **36**
Total **393/393 PASS**.
Original user photograph not committed; screenshot reference only.

## Next work
Confirm which of SW/SE and NW/NE is actually visible by independent image and physical evidence; measure rooftop camera polygon and correct foreground Cahill line. Build an independently georeferenced arch curve / pylon roof corners rather than centroid projections; use held-out observations and an error budget to qualify camera pose, or retain UNKNOWN.

Do not claim accuracy to metres from a perfect optimiser residual on unverified controls.
