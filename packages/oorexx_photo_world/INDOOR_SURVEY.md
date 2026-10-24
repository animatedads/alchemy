# Indoor survey evidence — dev20

## Corrected topology authority

The actual room is **not** represented by the dev18 Manhattan rectangle.
The projector screen is mounted on the face of an old **chimney breast** which
projects into the room.  The wall recedes into an **alcove/inset on both sides**
of that central projection.

The authoritative topology sequence is therefore:

`LEFT_ALCOVE_REAR -> LEFT_RETURN -> CHIMNEY_BREAST_FACE -> RIGHT_RETURN -> RIGHT_ALCOVE_REAR`

`SurveyChimneyBreastWallTopology` encodes that sequence explicitly.  The
projector-screen face is the chimney-breast face, not an alcove rear plane.

## Metric evidence retained without reinterpretation

| id | supplied wording / role | value | class |
|---|---|---:|---|
| left-wall-to-doorway | left wall to doorway | 2.750 m | MEASURED |
| opposite-wall | opposite wall | 3.750 m | MEASURED |
| long-wall | long wall | ~5.000 m | ESTIMATED PRIOR |

These observations are retained as measurements with their supplied semantic
roles.  dev20 **does not** remap 2.750 m and 3.750 m onto rectangle width/depth
axes and does not subtract them to manufacture a 1.000 m wall segment.

## Deliberately unresolved

The supplied evidence does not yet dimension:

- chimney-breast width;
- chimney-breast projection depth;
- left alcove width;
- right alcove width;
- exact doorway/jamb binding for the 2.750 m observation.

Consequently the exact floor area is also unresolved.  `SurveyIndoorActualRoomHypothesis`
returns no area until the missing dimensions are solved or measured.

## Image evidence

The existing Macrospace/OpenCV structural lane remains derived evidence only.
The next reconstruction step is to bind explicit image observations to this
correct wall topology and solve the missing segment dimensions/camera stations
through Photo Survey World + ooRexx Maths.  Python does not own the room model.


## dev21 structured image geometry

The six room photographs now cross the Macrospace boundary as explicit line
objects rather than opaque summary text. OpenCV LSD is a replaceable detector
only. Each accepted `(x1,y1,x2,y2)` observation is deposited into a live ooRexx
`SurveyImageSegmentCollection`; all vanishing-point consensus/refinement and
Manhattan orthogonality calculations occur in Photo Survey World using Maths.

At the current conservative 120-pixel minimum segment length the six views
produce 27 / 40 / 20 / 26 / 33 / 9 segments. Family counts after ooRexx solving
are 3 / 3 / 2 / 2 / 3 / 1. Lens selection is deliberately fail-closed: only
view 1 meets the <=0.20 orthogonality-RMS gate and supports the 80-degree
XCover-Pro main-lens prior. Views 2-6 are not promoted to a lens decision.

The corrected wall topology remains authoritative and its breast width, breast
projection, both alcove widths and exact doorway/jamb binding remain unresolved.
No dimension is extracted merely because a line detector found an edge.
