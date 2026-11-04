# Sydney Harbour V5V v0.30 — bounded source-resolution structural test

**Architecture:** user. **Native implementation and execution:** ChatGPT GPT-6, 2 November 2026. **Scope:** large cruise ship versus ordinary harbour traffic in two fixed-camera image regions. **Authority:** `OBSERVED_UNTESTED`. No general vessel identification, ship name verification, SLAM TESTED graph admission, or Power SLAM world coordinates.

## Actual source material

Four ORIGINAL user-uploaded videos (MPEG-TS despite `.mkv` filenames), all 30 fps:

| Camera / scene | Source SHA-256 |
| --- | --- |
| Camera 2 cruise | `6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830` |
| Camera 2 normal | `bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0` |
| Café Sydney Camera 3 cruise | `c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e` |
| Café Sydney Camera 3 normal | `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d` |

These originals were rehashed on this execution and match both v0.28 and v0.29 evidence manifests. The 28 source-resolution crops come from six previously unseen frame indexes **150, 450, 750, 1050, 1350 and 1650**, plus **frame 900**, using two previously reviewed, **manually selected and fixed** camera ROI rectangles. The crop geometry is *not* yet an autonomous V5V forecast or vessel detector:

- Camera 2: original 1280×720, rectangle **x365 y365 w150 h134**, 2.18% of source pixels.
- Camera 3: original 640×360, rectangle **x225 y95 w320 h184**, 25.56% of source pixels because the ship is closer and fills more of the camera.

`generate_features.sh` decodes just 7 original-source frames in one sequential FFmpeg invocation per original movie and extracts original RGB24 pixels without random seeking across mislabelled MPEG-TS. It verifies **all four original video SHA-256**, **all four v0.28/v0.29 frame-900 RGB24 reference hashes**, native crop sizes, then runs only the new C `ship_structure_native.c` on the crops. Its 28 `features.psv` rows are reproducible independently using `verify_rgb_receipts.sh`: **28/28 original-pixel hashes and 28/28 exact native features match**.

## New controlled structural test

The C code measures the fraction of brightness-greater-than-160 pixels in the bottom half of each crop, and the fraction with vertical luminance contrast above 22/255. The transparent structural score is **bright fraction + vertical-edge fraction**. The geometry stays at the *same original source-pixel rectangle* across cruise vs normal; the feature code itself does not know the claimed labels.

**Locking / heldout methodology:** The ooRexx `qualify_ship_structure.rex` derives its **one shared threshold 0.14064677** from *only the two Camera 2, frame 900* source crops (ship and normal). It applies a **0.010 abstention margin**. The other **26 source-crop observations are withheld from threshold selection**, including *all fourteen Camera 3 crops*, with labels drawn from previous scene-level human visual review. Results under ooRexx r13196:

| Qualification | Observations | Correct | Wrong | Abstain |
| --- | ---: | ---: | ---: | ---: |
| Camera 2 other times | 12 | 12 | 0 | 0 |
| Camera 3 completely held-out viewpoint | 14 | 14 | 0 | 0 |
| **Combined** | **26** | **26** | **0** | **0** |

The **minimum held-out ship-region structure score is 0.15543478**; the **maximum held-out normal-region score is 0.10985075**, leaving a separation inside this tightly controlled dataset. Both views have genuine small craft/wakes in the normal recordings. This does **not** prove generalisation to an independent recording, different ship, unseen weather, different camera crop, different ship position, or fully autonomous detection. Frames within each 60-second recording are highly correlated. There are only **two distinct recording periods**, and the site/scene labels are not independent field ground truth.

**Negative qualifications:** ooRexx refuses 12 distinct altered source/authority/schema/feature cases, and the byte-level native verifier catches two further forged RGB/feature receipts. All **14/14** negative controls rejected. A video/crop SHA alone does **not** cryptographically bind the reported feature values; production ingestion must invoke the pixel-exact native replay verifier, not accept an unattested features PSV.

## Why V5V still needs the second pass

Independent native C `v5v_keyframe_probe.c` decodes the *actual packed five-bit keyframe 900* from v0.28/v0.29 indexed blobs, verifies all 1800 ordered source-frame nodes per recording and source SHA, and measures a camera-specific ROI against another background-control region:

- Camera 2, palette 10: **19/110** cruise ROI cells versus **0/110** normal ROI cells; background control **0/143** in both. Strong site-specific coarse cue.
- Camera 3, palette 23: **432/984** cruise ROI cells versus **310/984** normal ROI cells, but the separate background control also changes from **177/460** to **246/460**. The apparent coarse contrast is **confounded by background/lighting**, so a V5V-only ship decision is inappropriate in that view.

The V5V full-cadence archive is the first-pass **observation/search index**; the high-res crop structural check is the second-pass **appearance evidence**. This v0.30 experiment evaluates already reviewed fixed ROIs rather than claiming that the native tracker automatically chose them. A production pipeline must chain: persistent V5V motion → bounded N-frame forecast → controlled AOI retrieval → source pixel shape → trained ferry/ship/nonvessel scoring with abstention → geometry via Power SLAM after calibrated pose certificate. The Water-mask and camera pose remain provisional; all geographic positions are blocked.

## Execution / reproduction

Reproduce from the four original source movies (the script refuses wrong file hashes):

```sh
gcc -O2 -std=c11 -Wall -Wextra -Werror ship_structure_native.c -o ship_structure_native
./generate_features.sh stream2_CRUISE.mkv stream2_NORMAL.mkv stream3_CRUISE.mkv stream3_NORMAL.mkv /tmp/v030
./verify_rgb_receipts.sh /tmp/v030/features.psv /tmp/v030/crops
rexx qualify_ship_structure.rex /tmp/v030/features.psv /tmp/v030/predictions.psv
./qualify_negative.sh /tmp/v030/features.psv /tmp/v030/crops /path/to/rexx
```

Optional: unpack `sydney_cruise_ship_v5v_three_camera_v0.28.zip` and `sydney_harbour_normal_traffic_v5v_v0.29.zip` and run `run_coarse_probes.sh cruise_v028_dir baseline_v029_dir` to verify the original packed five-bit V5V palette control.

**Archive:** scripts, exact original RGB24 crops and hashes, 28-row native features, 28 decisions with training/held-out partition, positive and corruption logs, coarse V5V audit logs, and reproducibility SHA256 manifest; **no original video source files or interpreter binaries** are redistributed. This is a **source-bound scene-specific structural evidence increment**, not a released ferry classifier.

### Source-coordinate correction (v0.31 audit, 2 November 2026)

The original FFmpeg YUV420 `crop` filter with requested odd source origins silently rounds x and y down to an even chroma-grid boundary by default. Thus this document's **nominal** source rectangles `x365 y365` and `x225 y95` actually retrieve RGB pixels beginning at **(364,364)** and **(224,94)** respectively. The exact original four frame-900 RGB SHA-256 hashes listed above have been independently reproduced at these corrected pixel origins. This is an image-region provenance correction, not a change in the recorded structural scores or test outcomes. v0.31's exact native RGB cropper explicitly avoids the implicit alignment adjustment. Do not treat the earlier nominal source coordinates as pixel-exact.
