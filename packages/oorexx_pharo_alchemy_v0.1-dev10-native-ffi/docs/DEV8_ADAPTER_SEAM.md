# dev8 runtime adapter seam
The lifecycle core now enters runtimes through a narrow adapter. `understands`
is passive and live; it cannot become cached dispatch authority. `send` preserves
missing-selector versus existing-method exception. retain/release remain
runtime-owned rooting operations.

The executable test uses a fake runtime to qualify the seam only. A concrete
Pharo 12 VM crossing is still NOT RUN.
