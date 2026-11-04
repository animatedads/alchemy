# Sydney Harbour V5V — Café Sydney / Customs House camera anchor v0.27a

**Architecture:** user. **Implementation and qualification:** ChatGPT GPT-6, 1 November 2026.

## Camera location and provenance

The user supplied **Level 5, Customs House, 31 Alfred Street, Circular Quay, Sydney** and approximate **northwest** orientation across the Cahill Expressway toward the Harbour Bridge. Stream 3, `stream3_20261101T120844Z.mkv` (640×360 H.264, 30fps), visibly carries the `CAFE SYDNEY` watermark. The building/restaurant address is corroborated by the [NSW tourism listing](https://www.sydney.com/destinations/sydney/sydney-city/city-centre/food-and-drink/cafe-sydney) and [City of Sydney lease record](https://meetings.cityofsydney.nsw.gov.au/ieDecisionDetails.aspx?Id=3799). Source SHA-256:

`08f2814c2d4033272a7c6532c3e5b340534ba16ad9fecc2d374d65324f9cab5f`

**Authority boundary:** known venue/building ≠ surveyed optical centre. Lens position, exact azimuth/elevation, intrinsics, water-plane registration and inter-camera clock offset remain **UNSURVEYED / UNCALIBRATED**. `camera_registry.psv` retains the other two unknown source locations rather than guessing.

`camera3_landmarks.psv` binds approximate 640×360 image regions on source frame 150 for Harbour Bridge, the foreground Cahill Expressway and the venue watermark. These are only image-reference regions. No imagery from the source labelled NOT FOR REBROADCAST is published in this directory.

## Executed independent native qualification

- ooRexx 5.3.0 r13196: **1,800/1,800** Stream 3 V5V source-indexed node rows checked against original PTS, SHA, record cadence and `OBSERVED_UNTESTED`. **60/60** keyframes.
- Six source-linked, human-reviewed vessel-candidate observations in Stream 3 checked against actual source hashes, PTS and crop hashes, not promoted to vessel identities. Trajectory x 525→386, y 197→213 in **50 seconds**: image-plane displacement **(-139,+16) px**, not world speed.
- Existing independent two-view source candidate predictor rerun: **8/8** held-out centres inside 5×5-cell bounded regions; shared physical identity still `CROSS_CAMERA_HYPOTHESIS_UNVERIFIED`. Camera 2 is Bridge-right and candidate moves image-right; Stream 3 is Bridge-left-of-centre and candidate moves image-left. Projected Bridgeward directions are visually consistent but not an inter-camera proof.
- **7/7** deliberate corruptions rejected (source SHA, false TESTED status, dropped frame, crop provenance, reversed trajectory, forged verified-identity claim, timestamp), fail-closed before output.

Full source-qualified runnable ooRexx validator, seven tamper tests, 6+6 original source-bound candidate receipts, original PTS arrays, full camera3 V5V node receipt and prediction output: **`sydney_customs_house_v5v_camera_anchor_v0.27a.zip`** (conversation file), SHA-256 `2bbb6a78ea822317b13d796670e469193693e9a845d29b5422858e07cdbb2166`. The raw user-uploaded video and runtime binary are not in the ZIP.

**Next work:** obtain surveyed camera lens coordinates or calibrate from image ground-control points, establish clock offset, then compare the two source-resolution ferry appearances and timings. Do not create canonical SLAM `TESTED` edges from this observation record.