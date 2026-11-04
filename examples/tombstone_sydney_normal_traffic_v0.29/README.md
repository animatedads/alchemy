# Sydney Harbour normal traffic — V5V source-bound cruise comparator v0.29

Architecture: user; native Vision/Camera method engines from original packages; baseline/comparison qualification assembled 2 November 2026.

## Original uploaded source evidence

- `stream1_20261102T062311Z.mkv` SHA256 `2636b416f57bcf0daff21cf5292b23ca0a791c2a3e82e32e850585d927bc2cad` (Bridge-left panorama, 1280x720)
- `stream2_20261102T062311Z.mkv` SHA256 `bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0` (Bridge-right/Opera House, 1280x720)
- `stream3_20261102T062311Z.mkv` SHA256 `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d` (Cafe Sydney / Customs House, 640x360)

All 3 have 1800 video frames, 30fps, approximately 60 sec H.264/AAC with an **actual MPEG-TS container**, although named `.mkv`. Audio was excluded from visual analysis, not modified in the authoritative upload. Original video files and unpacked 80x45 RGB24 working surfaces are omitted from the delivery archive.

## Canonical native V5V + ooRexx follow, executed

Native provider is identical to the previously supplied Vision dev22 palette/five-bit temporal-record implementation; this is indexed-surface reconstruction, **not** lossless source-video decoding or a new V5V API. All 5400/5400 indexed surface reconstruction checks passed under the C provider, with 60 keyframes/1740 deltas per source. Original PTS retained. The native line scanner and pure ooRexx r13196 threshold follower ran over all three streams and independent receipt verifier passed all three (also replayed earlier cruise evidence with identical masks/gates, 3/3 PASS). ooRexx threshold suite PASS 7/7.

| Metric | Now Stream1 | Cruise Stream1 | Now Stream2 | Cruise Stream2 | Now Stream3 | Cruise Stream3 |
|--|--:|--:|--:|--:|--:|--:|
| V5V bytes | 922135 | 921427 | 920818 | 921907 | 926274 | 924929 |
| Changed cells in water-admission mask | 2758 | 1938 | 727 | 2261 | 1987 | 3063 |
| Frames with unchanged indexed V5V surface | 606 | 614 | 453 | 388 | 1483 | 1569 |
| Components at configured detection lines | 200 | 239 | 82 | 268 | 170 | 142 |
| Two-observation motion hypotheses passing threshold | 32 | 35 | 6 | 48 | 14 | 14 |
| Bounded next-source-frame requests | 51 | 53 | 8 | 87 | 31 | 21 |

The water-mask assignment to Streams 1 and 2 was checked and corrected during the run before qualification. Same mask file **and identical gate geometry** are used for both time periods *per camera*. Stream 3 gate geometry is newly proposed and **PROVISIONAL_NOT_USER_TRACED**. Neither mask is a calibrated harbour water-plane polygon.

Totals: normal traffic 5,472 changed cells inside masks vs cruise 7,262; line-band components 452 vs 649; admitted motion hypotheses 52 vs 97; search requests 90 vs 161. **None of those totals is a vessel count or reliable large-ship classifier.** In Stream 3, for example, both clips have 14 admitted hypotheses although one clearly has an immense cruise ship and the other does not. More/less movement can reflect other vessels, weather, wake, camera compression, light and masks. New data remain `OBSERVED_UNTESTED`.

## Independently controlled same-ROI appearance comparisons

Source videos are ~28 min 35 sec apart by filename acquisition timestamps. From both Stream 2 and Cafe Sydney Stream 3, selected original **source frame 900** and decoded sequentially, without unreliable random seek on wrongly labelled MPEG-TS. Four crops use identical pixel rectangles for earlier cruise source and current baseline:

| Camera | Rect (x,y,w,h), source pixels | 16:54 cruise RGB24 SHA256 | 17:23 baseline RGB24 SHA256 |
|--|--|--|--|
| Stream2 | 365,365,150,134 | `e2738640ae7891690b60f554030112f15506fa3dff7be513de6d93a80edc2933` | `199b33525ab2a8630acefb9149f0381eb00c3ef113ddd978bf2e9e7fbe6d67d8` |
| Stream3 | 225,95,320,184 | `60e67bfd0428eb18030cdbafe0f0d9cb3d4c7179b22b1bb25034f34595cc129a` | `bf8c352d8816ed8f275c496ffbd37633233030d8627af5080820692025c8e851` |

Earlier cruise-image RGB hashes match the prior v0.28 recorded receipts exactly, independently validating the new extraction. Human visual review: the previous ROI contains the large white cruise liner and current ROI does **not** contain that liner, though small watercraft may be present. These four contrast examples are **reviewed samples only**, not a training/holdout validation set. Source hash, crop pixel rectangle, label and status are recorded in `reviewed_ship_vs_normal.psv` and evidence remains `OBSERVED_UNTESTED`.

## Reproduction and authority

`source/run_three.sh` requires the three original source files, FFmpeg/FFprobe, GCC and ooRexx r13196, plus suitable paths to native `librexx`. It checks every source format, 1800 PTS/frame correspondence and native output and runs native scanner plus independent ooRexx receipt verifier. Native code and actual ooRexx follow class/programs are bundled, unmodified from v0.26. Shell syntax and prior 7/7 threshold suite checked. 

Neither the 12 still images nor the 5,400 V5V nodes have been inserted into SLAM's canonical tested graph. Power SLAM remains responsible for camera geometry, but its real-site pose certificate is **not** established; no geographical boat position or shared-vessel cross-camera identity is inferred. This baseline provides a good hard negative for *the presence of a large cruise ship within those exact image regions*, not a universal negative for water traffic or vessel motion.