# Sydney V5V / Power SLAM v0.36 — topological camera landmark qualification

Architecture: user. Implementation and local native execution: GPT-6, 2026-11-02. Existing ferry owner: `tombstone-vision`; geometry owner: `power-slam-harbour`.

## Executed on source evidence

Read the **exact** six v0.35 Café Sydney 640×360 photo-image controls (`landmark_controls.psv`) from the user-supplied cruise and normal-traffic captures. Verified both original video SHA256s before qualification: cruise `c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e`, normal `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d`.

The real ooRexx 5.3.0 r13196 runner instantiates canonical Power SLAM `HarbourQuayInfrastructurePanorama` and actual v0.12 `HarbourBridgeRoofPins~frame`/`~localCoordinates`, with its four Google Earth **interior roof pins** (non-surveyed), plus canonical v0.8/v0.11 supporting classes. No source geometry was modified.

**Photographic approximate region centres:** left bridge tower x=48.5; arch-crown box x=174; right bridge tower x=322. These are broad image boxes, NOT exact visible roof midpoints, facade corners or survey points.

**Model azimuths at its provisional Customs House building point:** south pair midpoint **−9.527°** relative to north, north pair midpoint **+4.800°**. For the model's oversized **80m east-west × 64m north-south** hypothetical lens-placement rectangle:
- Mathematically exact *ordering only*: the 2D sightline cross product is affine in camera XY. All four rectangle corners have the same strict sign; both targets remain in front of all corners. Therefore **S to image-left of N** is invariant across the *entire rectangular envelope* given those hypothetical source controls. The arch-axis proxy bearing is between the two on the 99 sampled locations.
- The actual native 11×9 location sample of **99 camera sites** yielded **13.0028°–15.7383°** south-north angular separation. This is the *sampled* range, NOT a certified global angular interval, and it inherits the approximate model controls.
- Image-space order matches this topological constraint. It **does not** match image pixels to actual pylon roof corners, calibrate focal length, admit camera pose, generate occlusion masks, verify ferry identity, or provide world-space vessel position.

The native ooRexx source emitted a single `OBSERVED_UNTESTED` control receipt with `camera_pose=UNSURVEYED`, `pixel_to_world=BLOCKED_NO_QUALIFIED_TRANSFORM`, `identity=UNVERIFIED`.

**Qualification:** Positive genuine v0.35 image controls accepted; underlying Power SLAM roof-pin layout consistency passed; native 99 sampled candidate placements and continuous-rectangle order proof PASS; **13/13** changed/missing/forged source-region records rejected (including false TESTED/survey authority, invented model identity, swapped tower order, displaced arch, camera metadata and coordinate tampering). Run includes original user-video SHA256 gate. Test package executed again in a clean copied class-snapshot layout.

## Reproducibility

Complete self-contained *source snapshot* with actual ooRexx script `pylon_order_v036.rex`, `qualify_pylon_order_v036.sh`, read-only source-input/expected-result PSV, underlying Power SLAM v0.8/v0.11/v0.12 class snapshots (provenance only; **canonical owner remains Power SLAM**), test log, SHA manifest and `RUN.sh`: conversation artifact `sydney_power_slam_pylon_topology_v0.36.zip`, SHA256 `71b38272560ebba55936401d2968472a5b5384eab3546549c75910b4b8933d9e`. Original full video streams and ooRexx interpreter binaries excluded.

**Next genuine qualification gate**: obtain independent image-to-3D matches for individually identified pylon corners (with pixel uncertainty), fit camera XY/Z/yaw/pitch/focal using a held-out *independently georeferenced* landmark, and ask the Power SLAM geometry owner to certify uncertainty. Do not train a ship recogniser using these unqualified model pixels or erase V5V bridge/ship occlusion evidence.
