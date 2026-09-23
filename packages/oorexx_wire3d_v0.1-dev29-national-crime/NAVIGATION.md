# Wire3D dev21 navigation

Dev21 adds renderer-local navigation without changing application truth or the Maths-authored base scene matrices.

Desktop/demo controls:
- drag: orbit presentation around the current scene origin
- mouse wheel: dolly
- A/D or left/right: orbit
- W/S or up/down: dolly
- Q/E: pitch
- Tab / Shift+Tab: next / previous semantic object
- F: frame selected
- H or R: reset/home

Touch controls:
- one-finger drag: orbit
- pinch: dolly
- tap: select

The HUD supplies HOME, previous, FRAME and next so the demo remains recoverable without keyboard knowledge.
The dev20 framebuffer diagnostic is retained but hidden by default; append `?diag=1` to enable it.

Navigation is presentation state. It does not grant application authority and does not alter the authoritative model/view matrices supplied by ooRexx Maths v0.8. Semantic enter/leave remains a separate application-space operation.
