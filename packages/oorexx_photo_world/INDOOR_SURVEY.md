# Indoor survey evidence — dev18

## Authority

Measurements supplied by the surveyor outrank image/model estimates.

Current anchors:

| id | semantic role | value | class |
|---|---|---:|---|
| opposite-wall | room width | 3.750 m | MEASURED |
| long-wall | room length | 5.000 m | ESTIMATED PRIOR |
| left-to-doorway | opening anchor along reference wall | 2.750 m | MEASURED |

The 2.750 m record deliberately identifies an opening anchor, not a door width.
The precise jamb meaning can be refined when another endpoint measurement is
supplied without rewriting the original evidence.

## First solved hypothesis

`SurveyIndoorRoomSolver` uses ooRexx Maths to solve WIDTH and LENGTH from their
weighted constraints.  For the current observations this yields 3.750 x 5.000 m
and 18.75 m2.  Under this first Manhattan rectangle hypothesis the reference
span after the 2.750 m opening anchor is 1.000 m.

This does not assert that every wall face is perfectly rectangular.  A later
stepped/recessed footprint may supersede the envelope when explicit structural
image observations or measurements require it.

## Image evidence

The current six 1536 x 1152 photographs are processed through Python Macrospace
v0.31.6 by `PhotoWorldStructureProvider`, not inspected by an alternate ChatGPT
reconstruction path.  OpenCV LSD is used only as a replaceable structural-image
provider.  Its output is `STRUCTURE_RAW` evidence (counts and longest segment by
broad orientation family).  It cannot mutate `SurveyWorld` or promote itself.
