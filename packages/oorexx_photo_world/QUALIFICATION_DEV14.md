# Photo Survey World v0.1-dev14 qualification

Runtime used: ooRexx 5.3.0 r13196 Internal Test Version from the user-supplied 2026-09-25 debug package.

Maths dependency under test: supplied `oorexx_maths_v0.14.zip`.

## Executed regressions

The following tests were run individually under the real ooRexx runtime and each returned process status 0:

- `test_area_map.rex` — PASS area map model
- `test_bundle.rex` — PASS bundle projection
- `test_camera_rig.rex` — PASS rigid camera rig 10 mm vertical baseline
- `test_camera_specs.rex` — PASS camera catalogue
- `test_constraints.rex` — PASS explicit rigid-station constraint
- `test_inverse_geometry.rex` — PASS projection/inverse-ray consistency
- `test_maths_provider_payload.rex` — PASS Maths-owned provider payloads
- `test_move_resize.rex` — PASS move/resize/camera-height
- `test_photo_observation.rex` — PASS photo observation
- `test_registration.rex` — PASS explicit-control similarity registration
- `test_retail_topology.rex` — PASS Neilston retail topology

The dev14 run also repaired two pre-existing qualification blockers exposed by the real runtime: directive placement/path problems in several old tests, and a missing `expose _x _y _z` in `SurveyRigStation~cameraPosition`.

## Not executed

`test_python_provider_macrospace.rex` targets Python Macrospace v0.31.2 and was not executed because the v0.31.2 archive was not available in the current sandbox after the ChatGPT attachment limit problem. The source regression is included and explicitly exercises five-argument constructor, instance-method and classmethod crossings.

No claim of v0.31.2 runtime qualification is made by this Photo World package.
