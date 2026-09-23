# Dependencies

Hard runtime dependencies:

- ooRexx 5.3.0 r13196 qualification runtime
- ooRexx Maths v0.8
- ooRexx Vision v0.1-dev14-v5v-codec-highres (`VisionSurface`, V5V/high-res)
- ooRexx Line Assessment v0.1-dev1 (`LineAssessment` frame-local edge/run evidence)
- Wire3D v0.1-dev27-compatible semantic core for optional projection
- ooRexx distribution `json.cls` for JSON replay/scene serialization

Optional diagnostic dependency:

- ooRexx ML Graph v0.1-dev6 for V5V / motion overlays and trajectory diagnostics.

There is **no Python/OpenCV runtime dependency**.  Python/OpenCV is used only in
qualification probes against the supplied MP4 recordings.  The production
native-motion bridge consumes `VisionSurface` and Line Assessment directly.
