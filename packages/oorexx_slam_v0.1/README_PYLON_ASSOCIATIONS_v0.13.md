# Power SLAM Harbour v0.13 — photographed pylon identity alternatives

Architect: Tom Dyer. Implementation/measurement: ChatGPT GPT-6, 2026-11-01.
Rasen Falcon lane: `power-slam-harbour`. Camera position/status: **UNQUALIFIED**.

## Defect addressed

The v0.12 camera fitter used `S_TOP`, `N_TOP`, `S_DECK`, and `N_DECK`, which in the scene were **midpoints between two separate stone pylons** on each bank. A visible photographed tower cannot be assumed to occupy the midpoint of two different structures. Thus a low training reprojection error is not evidence of an accurate camera pose.

`SlamHarbourPinCorrespondence.cls` enumerates the four possible direct assignments of the two apparent tower locations in the 1536×862 image `1000066577.jpg`: south SW/SE × north NW/NE. Each assignment projects user Google Earth pin coordinates directly (`*_ROOF_PIN`, `*_DECK_PROXY`). Each pin is inside a roof, not a surveyed roof centre/corner. The approximate 50 m deck proxy and 89 m roof height remain model assumptions. Photo pixel annotations and physical identities are provisional.

## Rooftop fit comparisons

Actual ooRexx `fit_pin_correspondence.rex 18` output (local r13196):

| Identification | chi² training | Z ASL (m) | HFOV (°) | held-out arch crown reprojection error (px) | Camera bound | Admission |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| SW/NW | 0.257 | 45.17 | 34.82 | 109.5 | reached | BLOCKED |
| SW/NE | 0.424 | 42.75 | 37.44 | 75.2 | reached | BLOCKED |
| SE/NE | 0.588 | 42.81 | 34.15 | 34.9 | not reached | BLOCKED |
| SE/NW | 2.553 | 47.50 | 31.38 | 77.4 | reached | BLOCKED |

These solutions are **local optimisation hypotheses**, not measured camera elevations/FOVs. The arch point `(447,191)` is approximate and refers to a point modelled as a 134m-high centre of the main arch. The centreline geometry and local tangent approximation are themselves not independently surveyed. Thus the arch error is a *holdout warning*, not an absolute ground truth accuracy metric.

The three boundary solutions touch a deliberately overlarge, unsurveyed rectangular Customs House camera-area hypothesis, not a measured roof footprint. Even if a fit achieved a zero training or holdout error, it must remain blocked until the camera-area polygon and feature correspondences are qualified.

## Qualification

- `test_pin_correspondence.rex`: **36/36 PASS** with ooRexx 5.3.0 r13196 (rxmath). Tests enumeration of all four physical feature IDs, direct roof and deck Z coordinates, rejection of midpoint-name world lookups, polygon boundary handling, null-pose blocking, and fail-closed admission after perfect synthetic training fit.
- Existing eight suites v0.12: 357/357 PASS from last qualified local merged-source run, not independently rerun in this increment unless indicated by an accompanying log.

## Next required correction

Independently measure which of the four towers is seen in the actual 1536×862 photo, map each visible roof centre to a corresponding roof pin, survey the camera's permitted roof polygon, and measure the correct structure for each of the two deck-edge annotations. Then fit all six camera variables against those verified observations and repeat with several independent holdouts. Do not let low training chi² or a guessed rooftop position qualify a ferry world coordinate.

Source image is user-provided and intentionally not copied into public GitHub.