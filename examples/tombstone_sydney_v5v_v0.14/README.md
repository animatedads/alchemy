# Tombstone Sydney v0.14 — V5V-first evidence

This supersedes the OpenCV-centred design **architecturally**, not the earlier factual CV tracking evidence.

The user’s `vision/0.1` contract is a processable spatial-evidence codec, **not** a viewing or video playback codec. Its stable indexed `VisionSurface` samples, 5-bit/26-value representation, exact keyframe/delta records, sampling lattices, coherent change regions, line continuity, and evidence-backed high-resolution AOIs are the correct first stages. Camera Behaviour—not the codec—owns motion tracks and persistent object identities; SLAM consumes evaluated evidence, and raw video remains authoritative.

## Actual video experiment

Two uploaded Sydney Harbour H.264 mobile recordings, sampled via the source adapter at 5 fps and 80x45 *only for a mechanical baseline*. Each produces 26 Vision surfaces (3600 values, 5 bits each, 2250 packed bytes/keyframe), encoded through `V5VTemporalCodec` with keyframe period 10 and exact DELTA reconstruction. The source adapter uses FFmpeg to crop/decode/resample RGB24; **no OpenCV classifier or tracker runs**. A fixed 26-colour harbour scene palette uses a reusable 4-bit-per-channel lookup table rather than 26 RGB-distance calculations per pixel. This is **not** yet the production Vision three-curve adaptive palette.

- Manly recording: 26/26 reconstructed indexed surfaces exact, 3 KEYFRAME + 23 DELTA, mean 36.70 changed cells per delta (**1.019%**), 45 connected change regions of at least 3 cells.
- Earlier harbour recording: 26/26 exact, 3 KEYFRAME + 23 DELTA, mean 47.65 changed cells per delta (**1.324%**), 44 coherent regions.
- A neutral 26-level reference applied to the Manly recording gave 60.61 changed cells per delta (1.684%) and 78 regions. This is **not** an optimised-palette benchmark; it merely highlights how palette policy changes the evidence.

The 100% exactness claim applies only to the **indexed surfaces**, not the original RGB24 recording. Neither warm-colour labels nor temporal changes prove an object is a ferry.

The script uses canonical API method names and was exercised under ooRexx 5.3.0 r13196 against a **local test-only mirror of the specific relevant Vision classes** reconstructed from GitHub; the full current Vision package has **not yet** passed a test with this adapter. Keep it outside Vision core and request an independent checkout test.

## Reproduce

In an Alchemy checkout, with ooRexx 5.3.0 r13196 and `REXX_PATH` pointing at `packages/oorexx_vision/src`:

```sh
ffmpeg -hide_banner -loglevel error -i 1000066232.mp4 \
  -vf 'crop=1920:1080:210:0,fps=5,scale=80:45:flags=area,format=rgb24' \
  -frames:v 26 -f rawvideo -pix_fmt rgb24 ferry_80x45.rgb
rexx sydney_v5v_colour.rex ferry_80x45.rgb colour_evidence.psv 2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192
```

The script uses the normal `::requires 'V5VCodec.cls'` -> `Vision.cls` contract; no duplicate codec implementation is committed.

## Architecture for the next slice

1. **Geo sampling lattice**: retain stable water-plane metre coordinates alongside V5V sampled screen coordinates, using v0.12 approximate camera transform. Prefer sampling/coordinate mapping to repeated whole-frame image stretching.
2. **Temporal regions**: use `VisionSurfaceDelta` + connected change regions + Line Assessment; eliminate known fixed background as structural context without pretending moving water is static.
3. **Camera Behaviour**: associate persistent regions, view changes, direction, hull–water contact and track identity; **do not** put identity logic in V5V.
4. **Refinement**: when 80x45 cannot resolve the vessel, request higher-resolution source material with `VisionHighResolutionRequest` and `VisionRegionMaterial`, preserving source hash, frame timestamp, region and generation.
5. **SLAM evidence**: score bounded object hypotheses only after Vision/Behaviour evidence; keep `OBSERVED_UNTESTED` distinct from `TESTED`.

No SLAM graph integration, full colour-scene recognizer, geographic homography qualification, or source-owner approval is claimed.
