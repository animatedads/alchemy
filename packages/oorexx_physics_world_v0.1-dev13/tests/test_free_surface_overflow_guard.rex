numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry~new(.5,.2,.2,40)
slosh=.RectangularTankSlosh1D~new(water,tank,.015)
signal on syntax name expected
slosh~seedFundamental(.08)
signal off syntax
say 'FAIL free-surface overflow seed did not fail closed'
exit 1
expected:
  signal off syntax
  say 'PHYSICS FREE-SURFACE OVERFLOW GUARD: OK'
  exit 0
::requires 'FreeSurfaceFluids.cls'
