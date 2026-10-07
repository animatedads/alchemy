# Photo Survey World dev17 — ooRexx standards-enforcer review

Tool: `oorexx_standards_enforcer.py`

SHA-256: `978d0eb24cde13e014f2aeb61bccec1e6e6049792031c593e11407af17d545d8`

## dev15 findings repaired

The direct dev15 scan reported seven fatal findings. dev16 repairs all seven in source rather than suppressing them:

- `PhotoObservation.cls`: two `&` short-circuit assumptions replaced by explicit nested branches.
- `SurveyForeignProviders.cls`: depth-kind validation is an explicit `select`; metric-unit validation is nested; three locals named `result` are renamed to `foreignOutput`.

The affected regressions now exercise both branches that matter: cropped versus uncropped image dimensions and fail-closed invalid/metric depth construction.

## Remaining warnings

The enforcer reports six `PRIVATE_METHOD` warnings. These are reviewed and intentionally retained:

- `XCoverCameraSpecifications~buildCatalog`
- `XCoverCameraSpecifications~put`
- `SurveyAreaMap~pathStyle`
- `SurveyAreaMap~nodeFill`
- `SurveyAreaMap~esc`
- `SurveySvg~writeLines`

Every one is called synchronously from its owning class; none is sent as a `Message` activity. Source comments make that restriction explicit. Making them public only to achieve a warning-free strict scan would weaken encapsulation without improving the current execution path. If any future change sends one asynchronously, that change must first replace the private helper with an activity-safe public seam and add a crossing regression.

Dev17 retains those repairs and reruns the same enforcer against the release ZIP. Default policy passes with zero errors; the reviewed private-method warnings remain intentionally documented. Strict mode remains a useful deliberate audit mode and will flag those visibility warnings.
