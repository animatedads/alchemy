# Tombstone Sydney v0.19 — native region evidence + selective Vision source requests

Date 31 October 2026. Architecture: user. Executed on user-supplied ooRexx 5.3.0 r13196. All evidence: OBSERVED_UNTESTED. This package extends v0.18 with **real first-party Camera Behaviour track-region bounding-box observations** and **actual `VisionHighResolutionRequest` instances**, never an OpenCV tracker or inferred vessel identity.

## Source contract

Both original MP4s and source hashes verified in v0.18. Canonical Vision dev22 supplies V5V exact indexed-surface codec, `VisionSurfaceDelta`, `VisionChangeRegionExtractor` and `VisionHighResolutionRequest.cls`; the Camera Behaviour temporal tracker and quality gate use v0.18's explicitly disclosed method-extract-with-lookup-index variant. The new script modifies only evidence output, not temporal association or quality-gate decisions.

The video is a phone recording 2340×1080, containing a fixed webcam crop `crop=1920:1080:210:0`. A reduced 80×45 Vision sample corresponds to 24×24 pixels of the 1920×1080 crop. Camera `region` coordinate inputs are 1-based lattice positions. Native AOI mapping to the original phone pixels uses x=`210+(left-1)*24`, y=`(top-1)*24`; one-cell 24-pixel halo, clipped to x in [210,2130) and y in [0,1080). These coordinates are **original media pixels**, not world metres.

## Executed results

| Result | Manly 1000066232.mp4 | Other 1000066230.mp4 |
|---|---:|---:|
| Source-indexed surfaces | 156/156 exact | 130/130 exact |
| Camera motion tracks | 2,101 | 1,868 |
| Original Camera movement regions | 4,522 | 4,492 |
| **New preserved region rows** | **4,522** | **4,492** |
| Source requests built using native VisionHighResolutionRequest | 40 | 40 |
| Source requests fulfilled | 0 | 0 |
| Evidence authority | OBSERVED_UNTESTED | OBSERVED_UNTESTED |
| Region conservation tests | PASS | PASS |
| Corrupted-region negative tests | 6/6 rejected | 6/6 rejected |
| Full frame receipts vs v0.18 | byte-identical | byte-identical |
| Full track receipts vs v0.18 | byte-identical | byte-identical |

Both complete recordings were reprocessed through `sydney_v5v_camera_region_obs.rex` and completed under r13196. Each region carries track ID, frame, left/top/right/bottom, connected cells, maximum changed mask value, original source SHA-256 and `OBSERVED_UNTESTED`. The native `verify_camera_regions.rex` checks that every per-frame region count and every per-track observation count is conserved, and that region bounds and provenance cannot be forged or silently elevated.

The new `build_motion_aoi.rex` accepts the v0.18 longest 20 admitted motion-fragment shortlist and the native region file. It constructs **exact first-party** `VisionHighResolutionRequest` objects for the first and last region observations of each selected track, with explicit half-open media windows of 0.2 s and source-resolution pixel regions. This is a **request manifest**; no actual original-resolution crop has yet been retrieved or evaluated. Requested refinement never establishes a ferry identity.

## Source files

- `source/sydney_v5v_camera_region_obs.rex` — V5V+Camera observations with 6th region-PSV output argument, derived from v0.18.
- `source/CameraLumaTrackIndexed.cls`, `source/CameraLumaQualityIndexed.cls` — source-method excerpts of native Camera Behaviour, with an indexed ID lookup as declared in v0.18; **not** the full canonical Camera package.
- `source/verify_camera_regions.rex` — strict region/frame/track conservation validator.
- `source/qualify_camera_regions.sh` — six deliberate region tamper rejection cases.
- `source/build_motion_aoi.rex` — native high-resolution candidate request builder using Vision's existing public API.
- `evidence/{manly,earlier}.{frames,tracks,regions,aoi}.psv` — all source-linked receipt data.
- `qualification/{manly,earlier}.{native,negative}.log` — actual run and negative-test receipts.

## Remaining gates

1. The **full canonical Camera Behaviour dependency closure** has not passed integration; current runtime is a narrow method-extract qualification.
2. **No full-clip ferry object was recovered.** A quality-admitted native motion track is not automatically a vessel; long-lived water/wake/reflection fragments may be admitted. The longest fragment from v0.18 contains 22 samples.
3. The 80 source-resolution requests are **not fulfilled**. Independently measure true vessel shape, colour, hull–water contact and time continuity on requested original-resolution material before identity scoring.
4. The media-to-world homography and geographical speed remain unqualified. No metre-based output or SLAM `TESTED` graph mutation is permitted.

No MP4/RGB24 originals are included in the publication; their source hashes remain in every generated evidence row.