# Power SLAM Harbour PTZ sweep v0.16 — qualification

Architecture: Tom Dyer; implementation ChatGPT GPT-6. 2026-11-02. Rasen Falcon owner lane: power-slam-harbour. Ferry detector owner lane: tombstone-vision.

## Genuine recording
User-supplied video "WebcamSydney 2 Live Panning View of Harbour 247.mp4" from https://www.youtube.com/watch?v=jshwkG1ZpP8; actual format MP4 H264 + AAC, 1920 x 1080, 30fps, 7200 frames, 240.001451 s. SHA256 aa0d87c96d9a35c601632d81fa1592206f9a12bb6c3bd7af78cfe4873158bc45. User says PTZ shares north shore *building* with fixed camera. That is a provenance claim about premises, not proof of same optical centre.

## Native ooRexx repeat inference
FFmpeg is only a decode adapter to 1fps at 96x54 8-bit grey. The actual motion signature and period search is in SlamHarbourPtzCycle.cls (72 image block features, 3x3 samples per block, 60 pairs/lag).
Native ooRexx 5.3.0 r13196:
- Test synthetic repeat, malformed bounds, constant-scene caution and fail-closed state: 9 checks PASS.
- Anchor catalogue/admission: 12 checks PASS.
- Actual 240 frames: lag search 150..185 seconds, best 172 seconds, mean abs 7.43729427/255. Runner up mean abs 8.81067388/255; 60 overlapping samples. Frame-to-frame PTZ pan, tilt, and zoom trajectory **NOT** solved. Status **PTZ_PERIOD_CANDIDATE_UNQUALIFIED** because only one complete cycle plus a partial repeat.

Do not infer that every repeated skyline image indicates a complete physical camera motor-home rotation: static dwell may produce multiple similar frames.

## Additional landmarks
- Mosman fixed points: Bradleys Head Light (-33.853487, 151.246664), NSW heritage listing; South Mosman Wharf (-33.8433,151.2326) published approximate.
- Nearby, **not Mosman**: Robertsons Point Light (-33.8487833,151.2330139) on Cremorne Point.
- **Naval shipyard is Garden Island on southern shore, not Mosman**: Captain Cook Graving Dock reference point (-33.866406787364,151.22709774936) from Dictionary of Sydney, Garden Island naval precinct broad reference (-33.8654,151.2265). These are *source reference positions*, not surveyed outline polygons.
- Two named Mosman buildings: Clifford Residences 1 Musgrave Street; Mosman Rowers 3 Centenary Drive. They are currently **address-only** with roof coordinates and heights UNKNOWN; NOT_GEOREGISTERED and PHOTO_ASSOCIATION UNVERIFIED. Do not invent cuboids or use as metric camera constraints until roof corners and image projections are independently identified.

From unqualified north-shore v0.14 camera seed (-33.848741,151.214266), reference bearings approximately 70deg South Mosman Wharf, 90deg Robertson Light, 100deg Bradleys Head Light, and 149deg Captain Cook Dock; these ARE NOT PTZ pan angles. Correct geographic camera origin and lens remain unqualified.

## Safety and scope
No original video, captured still, rebroadcast footage, or live camera controls in Git. PTZ positions not treated as stationary; boats moving while the background pans cannot be scored as world displacement without per-frame admitted camera model. Existing v0.14 north shore and Blues camera poses remain BLOCKED; naval base point only public geographical background reference, not operational analysis.

Reproduction: `sh packages/oorexx_slam_v0.1/bin/run_ptz_cycle.sh /path/ptz-source.mp4 /tmp/power-slam-ptz` with FFmpeg and ooRexx installed.

Next: second full PTZ cycle, registered building/shoreline point correspondences in multiple angles, per-frame yaw/pitch/zoom motion estimation against camera building envelope; qualify actual location/pose with independent holdouts, maintain UNKNOWN ferry geo if not passed.
