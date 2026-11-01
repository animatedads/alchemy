# Power SLAM v0.4 — Circular Quay and Walsh Bay wharf geometry

**Architecture:** Tom Dyer. **Implementation and test:** ChatGPT GPT-6, 1 November 2026.

This is a simplified scene model, **not** a survey, topographical map, photo-derived reconstruction, or a claim that camera poses have been recovered. All images `*_wharves_360.svg/png` are output of ooRexx's `HarbourWharfPanorama` using `SlamHarbourPose.cls` geometry and the same three nominal onshore viewpoints at virtual height **50 m above sea level**. Every box is part of the scene and projects to an angular panorama.

## Fixed landmark additions

The baseline scene contains four bridge pylons, a deck, one white Opera House box, and one Salesforce Tower box (7 cuboids). The v0.4 addition creates two boxes per wharf, a thin deck and roofed wharf-shed body: 9 wharves x 2 = 18 more cuboids, **25 total**.

The sources below document the **identity and approximate geographic reference**, not the footprint, true pier tip, roof geometry, orientation or height. Dimensions for ALL wharves are hypotheses only.

| ID | Place | Geographic lat, lon used as representative point | Point status | Length x width, roof ASL **ESTIMATED** | Evidence |
|---|---|---|---|---|---|
| CQ2 | Circular Quay Wharf 2 | -33.860750, 151.212056 | Published stop point | 90 x 16 m; 8 m | [Sydney ferry wharves list](https://en.wikipedia.org/wiki/List_of_Sydney_Ferries_wharves) |
| CQ3 | Circular Quay Wharf 3 | -33.860667, 151.211500 | Published stop point | 90 x 16 m; 8 m | Same |
| CQ4 | Circular Quay Wharf 4 | -33.860639, 151.211000 | Published stop point | 90 x 16 m; 8 m | Same |
| CQ5 | Circular Quay Wharf 5 | -33.860583, 151.210500 | Published stop point | 90 x 16 m; 8 m | Same |
| CQ6 | Circular Quay Wharf 6 | -33.860545, 151.209970 | **Hypothesis**, extrapolated | 90 x 16 m; 8 m | Five-pier naming supported by [Circular Quay layout](https://en.wikipedia.org/wiki/Circular_Quay_ferry_wharf); no point independently verified |
| WB23 | Walsh Bay Pier 2/3 | -33.854895, 151.207063 | Published **nearby** monument, not pier survey | 165 x 24 m; 13 m | [Sydney Theatre Walk nearby location](https://www.monumentaustralia.org/themes/culture/social/display/94213-sydney-theatre-walk) |
| WB45 | Walsh Bay Wharf 4/5 | -33.855177, 151.205810 | Published structure reference | 175 x 25 m; 13 m | [Dictionary of Sydney: The Wharf](https://dictionaryofsydney.org/structure/the_wharf) |
| WB67 | Walsh Bay Pier 6/7 | -33.855620, 151.204600 | **Hypothesis** | 175 x 26 m; 15 m | [Identity / reconstruction](https://ptw.com.au/project/walsh-bay-piers-6-7), not site coordinate |
| WB89 | Walsh Bay Pier 8/9 | -33.856130, 151.203220 | **Hypothesis** | 175 x 25 m; 14 m | [Pier 8/9 delivery office mapped](https://mapcarta.com/W52751262), not a wharf-centre survey |

Walsh Bay contains finger wharves 2/3, 4/5, 6/7, and 8/9. Their identities, current form and relation to Hickson Road are documented by [NSW planning](https://majorprojects.planningportal.nsw.gov.au/prweb/PRRestService/mp/01/getContent?AttachRef=SSD-8671%2120190226T102050.067+GMT) and [a heritage survey](https://eplanning.cityofsydney.nsw.gov.au/Common/Integration/FileDownload.ashx?ext=PDF&filesize=4312547&id=%21%21Vs9uJ1%2FpAuBkKryXv5qvPomQBBeRr8NvDDaANQ%3D%3DY0C0GKKTT5I%3D&modified=2020-10-22T23%3A49%3A18Z).

**Rendering assumptions:** Circular Quay wharves all run north (bearing 0°) with 90m length. Walsh wharves run north-northwest along an assumed vector `(xEast=-0.37,yNorth=0.929)` with 165–175m lengths. Wharves have deck z=1.2–2.2 m, roof shed z=3m to the hypothetical roof height. These parameters are not validated against aerial-georeferenced footprints or accurate heights. No seabed, pier piles, roofs' architectural form, terrain, water surface or hidden-face removal is modelled.

**Safety:** `wharves[id]` explicitly carries `STATUS`, `SOURCE`, `SURVEYED_FOOTPRINT=.false` and `SURVEYED_ROOF=.false`. It is wrong to promote a successful projection test to site measurement, and the existing land-only camera mask remains a separate constraint. Finger wharves physically extend over water; **the blue-water prohibition applies to cameras, not to piers.** A virtual camera 50m ASL is not an assertion about public access to that height.

## Reproduce

Unzip v0.4 in a directory. With the user-supplied ooRexx 5.3.0 r13196 (`rxmath` on loader path):

```sh
export REXX_PATH=$PWD
rexx test_harbour_panorama.rex "$PWD"   # original 7-box regression
rexx test_harbour_wharves.rex "$PWD"     # new 25-box geometry and outputs
rexx render_harbour_wharves.rex "$PWD" # print azimuth of each new pier by viewpoint
```

**Qualified on ooRexx 5.3.0 r13196, 2026-11-01:** original panorama test 36/36 PASS; wharf test **145/145 PASS**; generated 3 SVGs, each with **450 `<polygon>` elements** (25 cuboids x 6 faces x three wrapped copies) within a valid `<svg>` root; rasterized SVGs into 3 PNGs with CairoSVG independently from the original ooRexx geometry. These are synthetic consistency tests, **not** photographic camera-pose accuracy tests.

## Follow-on criteria

1. Replace unknown geographic point anchors with actual OSM / cadastral or aerial-registration pier geometry, recording per-vertex accuracy and source vintage. Check current-year changes in terminal configuration. Never use measured markers derived from the reference panorama as independent truth.
2. Tie wharf corners to screenshots using landmark annotations separate from the geometry. Fit camera yaw/intrinsics with held-out landmarks.
3. Admit only a camera on a confirmed land mask and reject fits exceeding absolute pixel error, even if best among candidates. The inferred 3D location should remain a region until uncertainty has been constrained.

