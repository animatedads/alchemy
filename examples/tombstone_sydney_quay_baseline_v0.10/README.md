# Tombstone Sydney Quay baseline v0.10

Architecture: Tom Dyer. Coding and native tests: ChatGPT GPT-6, 31 October 2026. Additive to PR #106; not a SLAM core change.

## Datum

User's map screenshot on 31 October 2026 shows approximately 200 metres across the five Circular Quay ferry wharves. Treat as approximate frontage distance, not an independently surveyed straight-line chord with verified endpoint coordinates. Wharf 2 is the eastern end towards the Opera House; wharf 6 is the western end towards The Rocks.

The recorded source is USER_MAP_2026-10-31 with status APPROXIMATE_USER_MAP_READING. Endpoint pixel positions are UNKNOWN until corresponding structural reference points are marked in a native unzoomed webcam image. This produces LENGTH_RECORDED_IMAGE_UNLOCATED and no local metres/pixel value.

A later PIXEL_TIED_CANDIDATE requires original frame SHA-256, width/height, labelled east/west image coordinates and pixel_source MANUAL_IMAGE_MARKING. Only then is the approximate baseline secant scale 200 / image_chord_length_pixels computable. That value is not a global scale or ferry-world-speed estimate. SYNTHETIC_TEST_ONLY is explicitly labelled synthetic, never surveyed.

## Run

    rexx quay_baseline.rex user_map_approx.psv unlocated_result.psv
    python qualification_v010.py

Local native ooRexx 5.3.0 r13196: 16/16 PASS (two valid cases, fourteen deliberately corrupted or contradictory records rejected before writing output). The successful pixel-tied case uses synthetic (500,425) and (700,425) input coordinates to check one-dimensional arithmetic only.

Image coordinate normalization matters: v0.4 stills show 1260-pixel webcam content at screenshot x=138..1397, while the mobile video has native 1920-pixel webcam content within 2340-wide recordings. Raw screenshot x coordinates must not be compared across these two formats.

## Limits

One scalar distance is insufficient to solve a general planar homography with eight free parameters. The v0.9 native four-control and independent-heldout solver remains necessary, and measured water-plane correspondences have not yet been identified. The user 200m datum alone does not verify projected coordinate systems, camera pose or ferry speed. The end-on ferry classification miss and v0.8 OBSERVED_UNTESTED evidence remain unchanged.

Neither this code nor the map screenshot claims a surveyed authoritative baseline. Autobuilder, SLAM core and production deployment are untouched.
