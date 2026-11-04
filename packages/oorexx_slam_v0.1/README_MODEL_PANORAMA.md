# Power SLAM — three real-geometry 360-degree bearing views (v0.3)

**Architecture:** Tom Dyer. **Rendering implementation/test:** ChatGPT GPT-6, 1 November 2026.

These images are **not photographs or image-model illustrations**. They are 360-degree angular projections made by ooRexx from the *seven cuboids* in `SlamHarbourPose.cls` (four bridge pylons, bridge deck, Opera House box) plus a Salesforce Tower cuboid in `SlamHarbourPanorama.cls`. Their purpose is to test landmark ordering and approximate angular size. There is no terrain, skyline (except Salesforce), vegetation, vessel, road, bridge arch, or realistic façade. A visually rich generated image is useful as an illustration but **not** geometric ground truth.

## Camera sites (nominal geographic anchor; each camera z=50 m above sea level)

| site | lat | lon | note |
|--|--:|--:|--|
| Kirribilli House | -33.851286 | 151.219150 | Nominal building grounds point, not a surveyed 50 m camera platform |
| Circular Quay / Customs House | -33.862128338141 | 151.21083913743 | Approx. Customs House, not asserted as rooftop survey |
| Blues Point Reserve | -33.84973 | 151.20383 | Nominal reserve point, not a surveyed 50 m camera platform |

The underlying local tangent-plane approximation is from `SlamHarbourPose.cls`, with 92,300 m per degree longitude and 111,200 m per degree latitude in this region. It is intentionally simplified and is not a high-accuracy surveying model.

## World landmarks and modelling assumptions

| landmark | geometry |
|--|--|
| Harbour Bridge | 4 solid pylon cuboids, 1 deck cuboid; pylon reference points N at (-33.85003,151.21209), S at (-33.85454,151.20926) |
| Opera House | one white 183 × 120 × 65 m cuboid near (-33.8566674153,151.2152213360), with model base at 4 m |
| Salesforce Tower | one 45 × 45 × 263 m cuboid near (-33.862337,151.20865); model footprint width is **not surveyed** |

The camera z=50 metres ASL. All model cuboids have an assumed ground z. The `50 m` view is a virtual floating camera if needed; it does not certify a physically accessible platform.

## Model results: true north clockwise azimuth and camera-relative elevation

| viewpoint | bridge N | bridge S | Opera | Salesforce |
|--|--:|--:|--:|--:|
| Kirribilli House | 282.10° | 248.38° | 211.22° | 218.26° |
| Circular Quay | 4.91° | 350.20° | 33.67° | 263.45° |
| Blues Point Reserve | 92.51° | 136.86° | 126.27° | 162.39° |

**Interpretation:** the ordering is an objective prediction of this *specified* simplified model. For the Kirribilli viewpoint, an ordinary clockwise sweep places the Opera House before the bridge, while at Blues Point the Opera House bearing falls between the bridge's north and south reference points. A generated panorama depicting a conflicting order is evidence against *that generated depiction*, not proof that the specified camera coordinates or physics have changed. Compare against actual photographed features once accurately tagged and calibrated.

## Reproduction

Using the supplied ooRexx 5.3.0 r13196 and `rxmath`:

```sh
export REXX_PATH=/path/to/power_slam_harbour_v0.3
rexx render_harbour_panorama.rex /path/to/output
rexx test_harbour_panorama.rex /path/to/output
```

The output is `*_model_360.svg`; PNG versions are rasterizations of the SVGs without re-computing any geometry. Projection is linear azimuth 0–360° horizontal and elevation +55° to −35° vertical; the repeated polygons wrap around the 0° seam, allowing the Circular Quay bridge to straddle 350–5°.

## Qualification, 1 Nov 2026

- Renderer: 29/29 baseline math/site checks PASS.
- New SVG structure and angular-order regression: **36/36 PASS**.
- Independently parsed all three SVGs with `lxml`; each has **126 `<polygon>`** elements (= 7 cuboids × 6 faces × 3 wrap copies) *inside* the root; the closing SVG tag is at EOF.
- Independently converted to PNG with CairoSVG; nonempty coloured model structures are visible in each panorama.
- Fixed earlier output bug: a first build placed polygons after the closing `</svg>`, creating invalid images even though the numerical checks passed. The renderer now accumulates all SVG elements and writes them sequentially from one ooRexx method. The qualification detects recurrence.

### Limits

These runs do **not** identify where the original cameras were. The synthetic site projections should be compared to accurate pixel landmark measurements and actual coastline masks, using known or inferred camera intrinsics and a quantitative reprojection-error criterion. No photo is used as numeric truth by this demonstration.
