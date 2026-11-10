numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(.5,.3,.25,10,6)
slosh=.RectangularTankSlosh2D~new(water,tank,.03)

signal on syntax name expectedCfl
slosh~step(1)
signal off syntax
say 'FAIL 2D CFL violation did not fail closed'
exit 1

expectedCfl:
  signal off syntax
  slosh~resetFlat
  signal on syntax name expectedBottom
  slosh~step(.001,0,0,0)
  signal off syntax
  say 'FAIL 2D zero normal gravity did not fail closed'
  exit 1
expectedBottom:
  signal off syntax
  say 'PHYSICS FREE-SURFACE 2D FAIL-CLOSED: OK'
  exit 0
::requires 'FreeSurfaceFluids2D.cls'
