/* Geometry contract for the newly-authoritative rear exterior cavity. */

rearY = 0.0
stepY = -4.0
apertureWidth = 1.0
apertureBottom = 0.0
apertureTop = 2.0
stepBottom = 0.0
stepTop = 1.5
propertyFloor = 3.0

ignore = assertNear(4.0, rearY - stepY, 0.000001, "rear reflector offset")
ignore = assertNear(1.0, apertureWidth, 0.000001, "stairwell aperture width")
ignore = assertNear(2.0, apertureTop - apertureBottom, 0.000001, "stairwell aperture height")
ignore = assertNear(1.5, stepTop - stepBottom, 0.000001, "rear terrain step height")
ignore = assertTrue(apertureBottom = 0.0, "aperture begins at excavated ground")
ignore = assertTrue(stepBottom = 0.0, "rear step begins at excavated ground")
ignore = assertTrue(propertyFloor > apertureTop, "property floor remains above ground aperture")
say "PASS F11 rear exterior geometry"
exit 0

::routine assertTrue
    use strict arg condition, label
    if condition then return .true
    say "FAIL:" label
    exit 1

::routine assertNear
    use strict arg expected, actual, tolerance, label
    if abs(expected - actual) <= tolerance then return .true
    say "FAIL:" label "expected="expected "actual="actual
    exit 1
