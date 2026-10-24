# Photo Survey World v0.1-dev20 qualification

## Scope

dev20 corrects the actual indoor-room topology.  The projector screen is on a
central old chimney breast and the wall is recessed into an alcove on both
sides.  The dev18 rectangle remains only a generic solver regression and is no
longer the model of this room.

## Authority regression

`tests/test_indoor_chimney_topology.rex` requires the exact five-segment wall
profile:

`LEFT_ALCOVE_REAR -> LEFT_RETURN -> CHIMNEY_BREAST_FACE -> RIGHT_RETURN -> RIGHT_ALCOVE_REAR`

It also requires both alcoves to exist, requires the chimney dimensions to stay
unresolved, requires room area to remain uncomputed, and verifies that the
2.750 m, 3.750 m and ~5.000 m supplied metric observations survive without
being remapped into rectangle axes.

## Runtime

Qualification target remains Open Object Rexx 5.3.0 r13196 Internal Test
Version, 64-bit, build 3 Aug 2026, package SHA-256
`8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.

Final regression and standards-gate results are recorded after the release ZIP
is assembled so the standards tool is run against the actual deliverable.

## Executed dev20 results

The fourteen direct Photo World regressions were run under r13196 and returned
rc=0, including the new chimney topology regression and the generic rectangle
solver regression.  The exact bundled Maths v0.14 `test_math3d.rex` also passed
all 74 assertions.

The Macrospace/OpenCV structural lane is unchanged by dev20; its dev18 PASS is
retained as inherited evidence rather than falsely recorded as a fresh dev20
execution.
