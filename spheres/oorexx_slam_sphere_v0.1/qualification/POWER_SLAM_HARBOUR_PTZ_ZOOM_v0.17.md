# Power SLAM Harbour — PTZ relative zoom v0.17

Architect: Tom Dyer. Implementation and native qualification: ChatGPT GPT-6. 2026-11-02.
Rasen Falcon owner lane: power-slam-harbour; Tombstone Vision owns ferry evidence.

## Test source
User supplied WebcamSydney 2 Live Panning View of Harbour 247.mp4, source SHA256 aa0d87c96d9a35c601632d81fa1592206f9a12bb6c3bd7af78cfe4873158bc45; video source URL https://www.youtube.com/watch?v=jshwkG1ZpP8. The source video is NOT in Git. FFmpeg decode-only adapter produces 240 grayscale frames at 640x360, 1fps (55,296,000 bytes), SHA256 9eb28e1e86f959068302f6016269919e19d3441af3d70f016c83789500b5d77d.

## Native algorithm
SlamHarbourPtzScale.cls computes a horizontally differentiated intensity profile over y35..254 with 5/61-column scale band-pass, then optimizes 105 stationary-dominant skyline columns with normalized cross-correlation for relative 1D horizontal scale and shift. Does not require OpenCV, Python or external feature recognition; grayscale decode only through FFmpeg. Water and vessels can still enter sampled strip; this is NOT a fully static-object mask.

## Independent real video results
- 45 ->55 seconds: image scale 1.925, x translation -92 at 640px frame width, normalized correlation 0.643838732.
- 217 ->227 seconds: image scale 1.925, x translation -92, normalized correlation 0.645782570.
- 45 ->217 seconds (172-second repeat): scale 1.000, shift 0, correlation 0.994676973.
- 55 ->227 seconds (172-second repeat): scale 1.000, shift 0, correlation 0.995676721.
- A second native exploration of transition 48..52 seconds gives scale 1.0, 1.0, 1.2, 2.0, 1.95 respectively, with simultaneous horizontal translation; main two zoom comparisons are independently reproducible.

## Native qualification
With ooRexx 5.3.0 r13196 and the original recording, reproduced all four comparisons, and checked decoded source hash exactly. 13/13 new v0.17 scale/pan/repeat/rejection assertions PASS; 9/9 PTZ v0.16 cycle and 12/12 geographical anchor regressions PASS: combined 34/34.
Reproduction: sh packages/oorexx_slam_v0.1/bin/run_ptz_zoom.sh SOURCE_VIDEO /tmp/output.

## Admission
Result is REPEATED_APPARENT_ZOOM_CANDIDATE_NOT_LENS_CALIBRATED, not a calibrated optical focal change. A 1D image-scale match cannot prove lens rather than digital crop, true pan/tilt, motor schedule beyond a partial repeat, same optical centre as adjacent fixed webcam, nor any metric ferry position. Existing camera candidate poses are BLOCKED; do not promote to geographic ground truth. Next: fixed landmark association at many PTZ angles, per-frame 2D geometric registration with time-dependent yaw/pitch/intrinsics, independent holdouts and a true land-only mask.