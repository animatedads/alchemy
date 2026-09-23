# Wire3D projector tracking field — dev22

The tracking field is renderer/sensing infrastructure, not application state.
The ooRexx scene supplies a compact descriptor (`wire3d-tracking/1`, seed, density,
registration divisions and intensity). A renderer reconstructs the field locally.

The coordinate space is normalized projector space. The seeded constellation is
spatially unique and is combined with coarse registration points at multiple scales.
This is intended to let an external camera independently reconstruct the expected
background, register camera/projector coordinates, and treat occlusion as evidence.

The descriptor is deliberately independent of hand detection and gesture semantics.
No video frames or hand observations are part of WIRE-3D scene state.


dev23 qualification profile draws both deterministic registration lines and seeded stars at deliberately conspicuous intensity (0.62). The browser status bar reports FIELD ON when the descriptor is active.
