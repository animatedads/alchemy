call assertNear .Photometry~rectangleSolidAngle(0.01,0.01,0.02), 0.235430024, 0.00000001, 'solid angle 1cm square at 2cm'
call assertNear .Photometry~isotropicRectangleFlux(20,0.01,0.01,0.02), 4.70860048, 0.0000001, '20 cd exact rectangular flux'
call assertNear .Photometry~isotropicRectangleAverageIlluminance(20,0.01,0.01,0.02), 47086.0048, 0.01, 'average illuminance'
call assertNear .Photometry~inverseSquareIlluminance(20,0.02), 50000, 0.01, 'small-area approximation'
say 'PHYSICS PHOTOMETRY: OK'
exit 0

assertNear: procedure
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then do
    say 'FAIL' label 'actual='actual 'expected='expected
    exit 1
  end
  return

::requires 'PhysicsWorld.cls'
