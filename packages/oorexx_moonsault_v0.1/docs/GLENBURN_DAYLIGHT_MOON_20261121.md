# Glenburn, Scotland — 21 November 2026 daylight Moon validation

## Source separation
A user-supplied phone Gallery screenshot identifies a photograph captured at 15:44:59 local GMT (file label `20261121_154459.jpg`), with Gallery location tag "2–4 Skye Crescent, Glenburn, Paisley PA2 8EL", Samsung SM-G715FN and nominal 26 mm equivalent lens. The shared/rescaled JPEG is 1152×1536 and has no readable GPS EXIF, focal-length EXIF or capture timestamp in its file metadata. The screenshot is *an assertion about a Gallery-linked location*, not independently recovered GPS coordinates; **do not commit the private photograph, screenshot, or user identifying data**.

For independent prediction, use an approximate public postcode area-centre reference (55.822975° N, 4.431436° W), **not the photographer's numerical location**. The place is in Glenburn, Paisley, Scotland. The approximate 15:42 observation of an earlier photograph is a separate exposure from the screenshot's 15:44:59 photograph.

## Independent prediction and native ooRexx cross-check
Epoch: `2026-11-21T15:44:59Z` (UK winter GMT = UTC).
Independent Swiss Ephemeris topocentric calculation at public area-centre, observer height 60 m, assumed standard 1013.25 hPa and 2 °C:
- Moon true azimuth 88.82067° clockwise from north, true elevation +11.91300°.
- Sun true azimuth 230.62405°, true elevation +0.97898°.
- Moon waxing gibbous.

Existing archived Moonsault 2026-11-04 dev1 `MoonsaultEphemeris.cls` and the **user-supplied** ooRexx 5.3.0 r13196 interpreter executed `tests/test_glenburn_daylight_moon_20261121.rex` successfully:
- Moon azimuth 88.848276°, altitude +11.8992156° (differences 0.0276° az, 0.0138° alt);
- Sun azimuth 230.625282°, altitude +0.9821012° (differences 0.0012° az, 0.0031° alt);
- `status='PREDICTION_ONLY'` and no observation authority.
- Existing archived six-case ephemeris suite also passed locally.
The current PR branch revision includes later visibility metadata; this turn did **not** execute the complete branch version or pixel-camera calibration. Re-run the test on current head before merge.

## Navigation qualification boundary
The photograph visually contains the Moon above the eastward skyline. Its pixel coordinate, exact original optical geometry, camera roll/pitch, and actual GPS latitude/longitude are not yet measured. Therefore the photograph has **not** yielded an independently confirmed camera orientation or geolocation. A single Moon observation alone cannot generally solve both unconstrained camera pose and position. Do not claim a 1 NM fix, a 5 m survey result, or a field-qualified directional measurement from this prediction test.

Provenance for public area centroid: postcode PA2 8EL maps to approximately 55.822975,-4.431436 (Doogal postcode map). The phone screenshot address is a user-provided label. No private image bytes stored in Git.
