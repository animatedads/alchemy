# Tombstone Sydney geographical estimate v0.12

Architecture: user. Approximate unsurveyed camera model, not vessel navigation data. 31 Oct 2026.

Measured public anchors: bridge pylons 89m above sea level, main arch 503m, crest 134m, Opera House tallest sail 67m, building footprint 183x120m. These are all *vertical and structural* landmarks, not multiple surveyed ground control points. The map centroids of the north and south pylon are ~566m apart; this is NOT the 503m structural arch span.

Six manual base/tip webcam pixel observations were fitted with a six-parameter perspective camera model (focal 975px; principal pixel 960,540; camera height ~74m; latitude -33.848692, longitude 151.214669; heading 215.4 degrees SW). Fit RMS 5.32px. Systematic geographic uncertainty is far greater than the RMS suggests because visible roof peaks and projected pylon centres do not precisely correspond to the geolocated map centroids.

Circular Quay historical locality maps near -33.86109 151.21073, project to image pixel ~594,560. User's ~200m five-wharf frontage has no verified video endpoint pixels yet. Previous row-585 scale of 0.94m/px is a **different, nearer plane slice**, not verified berth spacing. Avoid calling that an independent calibration success.

Native ooRexx pixel->water-plane solver qualified on two prior video tracks: 158 and 130 points, net projected displacements ~103m/31s and ~110m/25.88s. Apparent ground speeds ~3.33 and ~4.26m/s. Because detector centroids are not reliable hull-water contacts, these rates are **preliminary model-derived estimates only**, not physical vessel-speed measurements. Cross-implementation comparison (Rexx against Python pinhole and OpenCV planar homography) PASS; 5 deliberate malformed inputs blocked with no evidence file (total 7/7 PASS).

A separate downloadable archive in the chat contains native ooRexx, complete input pixel tracks, estimated camera axes, projected tracks, 100-m frame grid, metric plan, model JSON, QA and checksum list. The raw mobile MP4 is not committed to GitHub. The current branch is PR #106; the numeric model is an additive external experiment and does not mutate SLAM graph or confer TESTED provenance.

Next: digitise exact quay wharf endpoints and 2+ extra independent shoreline points; recompute and compare the geographic estimator on heldout points. Preserve APPROXIMATE_UNSURVEYED until independently qualified.
