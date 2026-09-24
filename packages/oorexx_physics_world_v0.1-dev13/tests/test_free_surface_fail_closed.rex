numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry~new(.5,.2,.3,40)
slosh=.RectangularTankSlosh1D~new(water,tank,.015)

signal on syntax name expectedCfl
slosh~step(.Units~q(1,.Units~second))
signal off syntax
say 'FAIL free-surface CFL violation did not fail closed'
exit 1

expectedCfl:
  signal off syntax
  slosh~resetFlat
  signal on syntax name expectedBottomContact
  slosh~step(.Units~q(.001,.Units~second),0,0)
  signal off syntax
  say 'FAIL zero normal effective gravity did not fail closed'
  exit 1

expectedBottomContact:
  signal off syntax
  say 'PHYSICS FREE-SURFACE FAIL-CLOSED GUARDS: OK'
  exit 0
::requires 'FreeSurfaceFluids.cls'
