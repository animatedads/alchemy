/* Regression for unit mistakes: 66,200 lx over 1 cm^2 is 6.62 lm, not 0.00662 lm. */
lux=.PhysicsQuantity~new(66200,.SI~lux)
oneCm=.PhysicsQuantity~new(1,.SI~centimetre)
area=oneCm*oneCm
flux=lux*area
call assertNear flux~in(.SI~lumen),6.62,0.000000001,'66200 lx * 1 cm^2'

/* Exact direct geometry from the motivating example. */
exact=.Photometry~isotropicRectangleFlux(20,0.01,0.01,0.02)
call assertNear exact,4.70860048,0.0000001,'20 cd to 1 cm^2 square at 2 cm'

say 'PHYSICS QUANTITY PHOTOMETRY: OK'
exit 0

assertNear: procedure
  use strict arg actual,expected,tolerance,label
  if abs(actual-expected)>tolerance then do
    say 'FAIL' label 'actual='actual 'expected='expected
    exit 1
  end
  return
::requires 'PhysicsWorld.cls'
