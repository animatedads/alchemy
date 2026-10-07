numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry~new(1,.20,.30,80)
slosh=.RectangularTankSlosh1D~new(water,tank,.04)
expected=2*tank~length/RxCalcSqrt('9.80665'*slosh~meanDepth,30)
call near slosh~fundamentalPeriod,expected,'shallow-water fundamental period','0.0000000001'
slosh~seedFundamental(.01)
initialX=slosh~centreOfMassLocal~x
half=slosh~fundamentalPeriod/2
elapsed=0
do while elapsed<half
  dt=.001
  if elapsed+dt>half then dt=half-elapsed
  slosh~step(dt)
  elapsed=elapsed+dt
end
if initialX*slosh~centreOfMassLocal~x>=0 then do
  say 'FAIL fundamental slosh did not reverse centre-of-mass sign after half period' initialX slosh~centreOfMassLocal~x
  exit 1
end
say 'PHYSICS FREE-SURFACE SLOSH FREQUENCY: OK period='slosh~fundamentalPeriod 'x0='initialX 'xHalf='slosh~centreOfMassLocal~x
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'FreeSurfaceFluids.cls'
::requires 'rxmath' LIBRARY
