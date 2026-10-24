# Image geometry — dev21

## Authority split

`photo_world_structure_provider.py` performs replaceable 2-D line detection only.
For every accepted long segment it calls the live ooRexx collector with its two
endpoints and a coarse detector-family label. The provider does not calculate a
vanishing point, camera pose, lens selection, wall identity or physical length.

`SurveyImageGeometry.cls` owns the survey-side interpretation. Each segment is
converted to a normalized homogeneous image line. Candidate vanishing points are
pairwise line intersections. Consensus uses undirected angular agreement and
length weighting. The selected consensus is refined by weighted perpendicular
line-distance least squares through the Maths matrix solver. Inliers are removed
and the process repeats for up to three line families.

For a three-family result, `SurveyManhattanLensCheck` converts each image
vanishing point into a camera-direction `MathVector3` using the tested diagonal
FOV. Pairwise dot products are zero for an ideal Manhattan triad. The RMS of the
three absolute orthogonality errors is diagnostic evidence only.

## Fail-closed lens gate

The current acceptance threshold is RMS <= 0.20. A candidate which merely has a
lower score than another candidate does not win when both are poor. On the six
current room photographs only view 1 passes this gate and supports the nominal
80-degree main-lens prior. The other views remain unresolved.

## What dev21 does not claim

- no automatic wall or chimney semantic labelling;
- no camera translation;
- no room dimensions from image lines;
- no chimney-breast width or projection depth;
- no alcove widths;
- no pixel-to-world promotion without an explicit later correspondence step.
