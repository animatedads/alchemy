numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry~new(.Units~q(1,.Units~metre),.Units~q(.20,.Units~metre),.Units~q(.35,.Units~metre),80)
slosh=.RectangularTankSlosh1D~new(water,tank,.Units~q(40,.Units~litre),0,.45,.Units~q(.5,.Units~millimetre))
slosh~seedFundamental(.Units~q(2,.Units~centimetre))
initialVolume=slosh~currentVolume
initialMass=slosh~currentMass
initialRange=slosh~surfaceRange
if initialRange<.035 then do; say 'FAIL seeded slosh surface range' initialRange; exit 1; end

do n=1 to 1200
  slosh~step(.Units~q(.001,.Units~second))
end
call near slosh~currentVolume,initialVolume,'free-surface volume conservation','0.00000000001'
call near slosh~currentMass,initialMass,'free-surface mass conservation','0.00000001'
if slosh~surfaceRange<=0 then do; say 'FAIL slosh wave vanished'; exit 1; end
if slosh~minSurfaceDepth<=0 then do; say 'FAIL slosh produced dry cell'; exit 1; end
if slosh~maxSurfaceDepth>=tank~height then do; say 'FAIL slosh overflowed tank'; exit 1; end
say 'PHYSICS FREE-SURFACE SLOSH MASS: OK volume='slosh~currentVolume 'range='slosh~surfaceRange
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'FreeSurfaceFluids.cls'
