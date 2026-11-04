# Tombstone Sydney v0.17 — full original-clip V5V qualification

Architecture: user. Native qualification: GPT-6, 31 October 2026 UTC. Additive to PR #106.

## Source and execution

- Original Manly recording `1000066232.mp4` — SHA-256 `2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192`.
- Original earlier recording `1000066230.mp4` — SHA-256 `6f19614717fad0bddab8d3208dbc4d97b1ab774236445146878b2c6035c017fb`.
- Original MP4 bytes recovered from Library; source hashes reverified.
- **Fresh FFmpeg decode** (`crop=1920:1080:210:0,fps=5,scale=80:45:flags=area,format=rgb24`) compared byte-for-byte using `cmp` with both archived complete source-derived RGB24 feeds from v0.15: **MATCH, MATCH**.
- Canonical first-party `Vision.cls`, `V5VCodec.cls`, `VisionSurfaceDelta`, `VisionChangeRegionExtractor` in the Library's `oorexx_vision_v0.1-dev22-temporal-intentions.zip`.
- Existing first-party V5V consumer `tombstone_sydney_v5v_v0.14/source/sydney_v5v_colour.rex` run on the **full 156 + 130 frames**, rather than the old 26-frame slice.
- User-provided ooRexx 5.3.0 r13196 Debian package used without replacing the Vision codec or inventing another tracker. All source-media references retained. Video is *not* committed to GitHub.

## Measured native V5V results

| Source | Indexed surfaces exact | Keyframes | Delta frames | Changed cells in deltas | Mean per delta | Connected regions >= 3 | Warm-palette cells |
|---|---:|---:|---:|---:|---:|---:|---:|
| Manly | 156/156 | 16 | 140 | 5,013 | 35.807 | 195 | 10,211 |
| Earlier | 130/130 | 13 | 117 | 4,922 | 42.068 | 218 | 9,249 |

Exact reconstruction refers **only to the reduced five-bit/26-value indexed VisionSurface**, not RGB24/H.264. Region counts are the existing Vision class's connected-change measurements, not Camera Behaviour tracks or ferry classifications. Timing is the v0.14 consumer's 5 fps sampled `frame/5` timeline.

## New native receipt qualification

`verify_v5v_full.rex` executed on both native PSV streams: **2/2 PASS**. Checks exact 156/130 source frame counts, frame chronology, keyframe schedule and 3,600-cell keyframe size, fraction consistency, 5-bit evidence cell bounds, source SHA provenance, roundtrip flag, and strictly `OBSERVED_UNTESTED` state.

`qualify_v5v_receipts.sh` ran seven deliberately corrupted versions against real source receipts: **7/7 rejected** (forged first keyframe; forged `TESTED`; forged source SHA; dropped final frame; wrong delta cadence; repeated index; appended extra frame). Both scripts are tested on r13196; `rexxc -s` of the verifier passed.

Source-derived RGB24 SHA-256: Manly `07aaba67e65f45dcd2886ad6215e395446ff017bc9ec2cbc8e9598032a882692`; earlier `3e0929c3383264cf5cc6ceadf40996c90e703bbb29d0c1384a967a004e8a7fa2`.

## Reproduce

With the canonical dev22 `Vision.cls` and `V5VCodec.cls` on `REXX_PATH`, pass the two complete decoded RGB24 feeds into the existing v0.14 `sydney_v5v_colour.rex`, passing the respective original MP4 SHA-256 as the sourceHash argument. Then run:

```sh
rexx verify_v5v_full.rex manly.psv earlier.psv
REXX_BIN=rexx sh qualify_v5v_receipts.sh manly.psv earlier.psv
```

The complete local qualification ZIP includes both evidence PSV receipts, the two native scripts, README, and checksums. GitHub keeps the scripts and this reproduction record; original MP4 material is excluded.

## Motion and SLAM acceptance gate

**Camera Behaviour temporal track association is still NOT_RUN.** The existing v0.16 `sydney_v5v_camera_motion.rex` correctly targets `CameraLumaTemporalTrackSet` and `CameraLumaBehaviourBridge`, but a complete canonical `camera_behaviour_oorexx_v0.56` source checkout was unavailable for native runtime qualification here. Do not substitute OpenCV tracking, reconstructed camera classes, or an invented motion count. The next canonical acceptance gate is to run v0.16 `run_both.sh` with the genuine Camera dependency tree and persist its per-track evidence, then test an explicit SLAM admission adapter. Neither the ~200 m wharf baseline nor tentative geographic overlays qualify a water-plane homography or velocity in metres. All new observations stay `OBSERVED_UNTESTED`.
