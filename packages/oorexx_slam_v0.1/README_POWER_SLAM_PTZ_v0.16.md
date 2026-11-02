# Power SLAM v0.16 — panning webcam recurrence and eastern harbour anchors

**Architecture:** Tom Dyer. **Implementation:** ChatGPT GPT-6 (2026-11-02). **Lane:** `power-slam-harbour`. No ownership of `tombstone-vision` ferry detection.

## Source and evidence

Video: user-provided `WebcamSydney 2 Live Panning View of Harbour 247.mp4` from https://www.youtube.com/watch?v=jshwkG1ZpP8. The video is MP4/H.264 (unlike earlier mislabeled MPEG-TS files), 1920×1080, 30fps, 7200 frames, 240.001s; source SHA-256 `aa0d87c96d9a35c601632d81fa1592206f9a12bb6c3bd7af78cfe4873158bc45`. **The source video, its decoded frames and screenshots are not committed to public Git.** The 24-frame private contact sheet was generated from this actual recording.

User identifies WebcamSydney 2 as a scheduled panning camera co-located in the same building as north shore fixed camera. **Same building does not imply identical optical centre**. Refit PTZ per frame yaw, pitch and zoom using fixed roof XY hypothesis with uncertain mounting offset; avoid tying it to current unqualified v0.14 north-shore camera XYZ.

## Actual 172-second repeat candidate

Video decoded through FFmpeg (source adapter only) to 1fps, 96×54 grayscale. `HarbourPtzCycle` written entirely in ooRexx computes 72 block signatures per sampled frame (3×3 pixel means for 12×6 spatial grid), then searches delay 150–185 seconds over up to 60 paired samples. On 240 actual 1fps frames:

```
source_frames=240
period_seconds=172
mean_abs_8bit=7.43729427
runner_up_mean_abs_8bit=8.81067388
overlap_pairs=60
status=PTZ_PERIOD_CANDIDATE_UNQUALIFIED
```

Native ooRexx 5.3.0 r13196 synthetic cycle test: 8/8 PASS. Geographic anchor/admission test: 12/12 PASS. The best lag is stable in exploratory image-reference comparisons too. Since only one full cycle is included, this is **one-cycle recurrence**, not a qualified schedule and not a continuous PTZ motor position calibration. Fixed camera features must be matched again after a pan or preset change; do not confuse ferry movement with background motion.

## Eastern fixed geography for prolonged sweep

`HarbourPtzAnchors` contains five **typed reference points**, not fabricated surveyed cuboids:

| ID | Lat | Lon | Evidence/precision |
|---|---:|---:|---|
| `BRADLEYS_HEAD_LIGHT` | -33.853487 | 151.246664 | NSW Heritage item 5051364; Mosman |
| `SOUTH_MOSMAN_WHARF` | -33.8433 | 151.2326 | published approximate wharf location; Mosman |
| `ROBERTSONS_POINT_LIGHT` | -33.8487833 | 151.2330139 | published nearby Cremorne Point light; **not Mosman proper** |
| `CAPTAIN_COOK_GRAVING_DOCK` | -33.866406787364 | 151.22709774936 | Dictionary of Sydney structure point, Garden Island; **not Mosman** |
| `GARDEN_ISLAND_NAVAL_PRECINCT` | -33.8654 | 151.2265 | published broad area reference, **not dock centre** |

Two real Mosman waterfront **buildings** are also named, but withheld from projection until their rooftop corners are georegistered and the webcam image proves visibility:

- `CLIFFORD_RESIDENCES`, 1 Musgrave Street, Mosman — beachfront block named by local real estate listing. Coordinate/roof height **UNKNOWN**, image association **UNVERIFIED**.
- `MOSMAN_ROWERS`, 3 Centenary Drive, Mosman — waterfront historic clubhouse (official business address). Coordinate/roof height **UNKNOWN**, image association **UNVERIFIED**.

The tall tan apartment blocks appearing close to the PTZ camera in the eastward view are **not identified as Mosman buildings**. They may be much closer to the northern-shore camera and produce useful parallax once their addresses can be established. Do not invent roof coordinates.

Relevant sources: https://apps.environment.nsw.gov.au/dpcheritageapp/ViewHeritageItemDetails.aspx?ID=5051364 ; https://dictionaryofsydney.org/structure/captain_cook_dock ; https://www.navy.gov.au/about-navy/bases-and-locations/fleet-base-east ; https://www.raywhite.com/nsw/mosman/2405870 ; https://www.mosmanrowers.com.au/contact-us .

## Qualification states / contracts

- PTZ movement: `PTZ_PERIOD_CANDIDATE_UNQUALIFIED`, 172 s one-cycle repeat.
- Three fixed source cameras v0.15: `FRAME_STABLE_POSE_UNQUALIFIED` for own 60-second recordings. New PTZ is **not fixed**.
- Feature associations: `UNVERIFIED` for all new eastern reference points until an actual pixel landmark is matched.
- Two Mosman buildings: `NOT_GEOREGISTERED` and no 3D cuboid / no guessed rooftop height.
- Garden Island: public dock and naval-base **geographic background landmark**, not ship-tracking or restricted base surveillance.
- Ferry world coordinates: `UNKNOWN` without separately admitted camera pose / water-plane geometry.

## Reproduction

With ooRexx r13196 and FFmpeg, from repo:

```
sh packages/oorexx_slam_v0.1/bin/run_ptz_repo.sh \
  '/path/to/WebcamSydney 2 Live Panning View of Harbour 247.mp4' \
  /tmp/power-slam-ptz
```

Reference sources in `packages/oorexx_slam_v0.1/src/SlamHarbourPtzCycle.cls` and `SlamHarbourPtzAnchors.cls`; test scripts in `tests`. Use the exact video SHA above when interpreting the reproduced measurements. To establish a true schedule, collect a second full repeat and validate the cycle period against it; then fit static landmarks to solve yaw/pitch/focal for each identifiable preset.