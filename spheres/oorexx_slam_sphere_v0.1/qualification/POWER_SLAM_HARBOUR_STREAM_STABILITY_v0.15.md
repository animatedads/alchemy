# Power SLAM Sydney Harbour — three-camera stream stability v0.15

Architecture: Tom Dyer. Native ooRexx implementation: ChatGPT GPT-6. Date: 2026-11-02.
Rasen Falcon lane `power-slam-harbour`. Tombstone Vision continues to own ferry recognition. The real camera 6DoF locations are **not accepted**, and the numerical v0.14 pose estimates remain hypotheses.

## Recorded sources

Three user-supplied 60-second **MPEG transport streams** misnamed `.mkv`, 30 fps H.264. Stream 1: 1280x720, western/Blues view; stream 2: 1280x720, north-shore view; stream 3: 640x360, Cafe Sydney. All H.264 tracks have 90kHz PTS and start at 1.400s. Exact source SHA256 and reproduction commands in `packages/oorexx_slam_v0.1/README_STREAM_FRAME_QUALIFICATION_v0.15.md`. No video or source photographic image bytes distributed in Git. Stream 1 contains a Not For Rebroadcast watermark.

## Native ooRexx measurement

`SlamHarbourStreamStability.cls` uses 320x180 grayscale fixed-ROI patch comparison after FFmpeg decode-only sampling every 15sec (four frames per stream). Independent native patch-matching algorithm, bounded +/-3px template search, texture/edge/change gate; no OpenCV or external image classifier. First-order transform from 1536x709 screenshot with 138px sidebars to full-resolution 1280x720 camera frame is preserved and checked.

Measured from actual user recordings: 11 fixed ROIs and 33 sample-to-baseline comparisons. At 320x180 all 33 displacement best-matches are (0,0), **not** subpixel zero. Mean 8-bit patch MAD by feed: 1.54, 0.57, 2.60; max 2.52, 0.92, 5.92. `FRAME_STABLE_POSE_UNQUALIFIED` is not permission to resolve camera XY, elevation or ferry geolocation.

## Displayed clock offset

Manually transcribed clocks at four matched relative offsets 7.5/22.5/37.5/52.5sec: stream1 17:23:06/21/36/51; stream2 17:23:01/16/31/46. Stable +5sec *displayed clock difference*. `SlamHarbourClockEvidence.cls` qualifies only `STABLE_DISPLAY_CLOCK_OFFSET_NOT_FRAME_SYNC`. Same PTS convention and 5sec clock difference **do not** prove simultaneity, server ingestion offset, or real-time synchronization. Stream3 has no comparable digital clock.

## Reproduction and tests

`sh packages/oorexx_slam_v0.1/bin/run_harbour_stream_stability.sh stream1 stream2 stream3 /tmp/output` calls ffmpeg as source adapter and native ooRexx tests/measurement. Full repo-layout runner rerun against all original sources, producing byte-identical `stream_stability.tsv`.

Native ooRexx 5.3.0 r13196: 16/16 new image stability qualification tests, 12/12 new clock-gate tests; 33 user video patch measurements. Previously 38/38 v0.14 and 36/36 v0.13 tests rerun. New implementation changes no camera-service configurations or ferry detector. Do not combine temporal stability with a false geographical pose admission.

## Next
Refine 1280x720 and 640x360 landmark pixel correspondences on temporally stable source frames, verify camera actual building/roof and independent bridge roof corners and arch locus. Model geographic camera and lens uncertainty until holdouts agree. Establish synchronization from observed common ferries only with independent source-clock provenance, never by equating nominal frame indices across different cameras.
