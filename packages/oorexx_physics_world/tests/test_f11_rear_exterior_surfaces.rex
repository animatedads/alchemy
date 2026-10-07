/* Executable surface contract for rear terrain reflector and stairwell opening. */
numeric digits 20
ctx = .Maths~defaultContext
freq = .array~of(125, 500, 1000, 2000, 4000)
block = .AcousticBuildingMaterialFactory~breezeBlockWall(freq)
collector = .SurfaceCollector~new
count = .F11RearExteriorGeometry~addToSolver(collector, block, freq, ctx)
ignore = assertEqual(7, count, "surface count")
ignore = assertTrue(collector~has("REAR_TERRAIN_STEP"), "rear terrain reflector exists")
ignore = assertTrue(collector~has("STAIRWELL_REAR_JAMB_LEFT"), "left aperture jamb exists")
ignore = assertTrue(collector~has("STAIRWELL_REAR_JAMB_RIGHT"), "right aperture jamb exists")
ignore = assertTrue(collector~has("STAIRWELL_REAR_LINTEL"), "aperture lintel exists")
ignore = assertNear(1.0, .F11RearExteriorGeometry~apertureXMax - .F11RearExteriorGeometry~apertureXMin, 0.000001, "opening width")
ignore = assertNear(4.0, .F11RearExteriorGeometry~REAR_PROPERTY_Y - .F11RearExteriorGeometry~REAR_STEP_Y, 0.000001, "step offset")
ignore = assertNear(1.5, .F11RearExteriorGeometry~REAR_STEP_TOP_Z, 0.000001, "step height")
say "PASS F11 rear exterior surfaces"
exit 0

::routine assertTrue
    use strict arg condition, label
    if condition then return .true
    say "FAIL:" label
    exit 1

::routine assertEqual
    use strict arg expected, actual, label
    if expected == actual then return .true
    say "FAIL:" label "expected="expected "actual="actual
    exit 1

::routine assertNear
    use strict arg expected, actual, tolerance, label
    if abs(expected - actual) <= tolerance then return .true
    say "FAIL:" label "expected="expected "actual="actual
    exit 1

::class SurfaceCollector
::method init
    expose names
    names = .directory~new
::method addSurface
    expose names
    use strict arg surface
    names[surface~name] = surface
    return surface
::method has
    expose names
    use strict arg name
    return names~hasIndex(name)

::requires '../rexx/F11RearExterior.cls'
