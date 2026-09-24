numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(.Units~q(1,.Units~metre),.Units~q(.6,.Units~metre),.Units~q(.4,.Units~metre),12,8)
slosh=.RectangularTankSlosh2D~new(water,tank,.Units~q(.12,.Units~cubicMetre),.02)
slosh~seedStandingMode(.Units~q(1.5,.Units~centimetre),.Units~q(1,.Units~centimetre))
initialVolume=slosh~currentVolume
initialMass=slosh~currentMass
if slosh~surfaceRange<.03 then do; say 'FAIL 2D seeded surface range'; exit 1; end

do n=1 to 200
  slosh~step(.002)
end
call near slosh~currentVolume,initialVolume,'2D free-surface volume conservation','0.0000000001'
call near slosh~currentMass,initialMass,'2D free-surface mass conservation','0.0000001'
if slosh~minSurfaceDepth<=0 then do; say 'FAIL 2D slosh dry cell'; exit 1; end
if slosh~maxSurfaceDepth>=tank~height then do; say 'FAIL 2D slosh overflow'; exit 1; end
if slosh~freeSurfacePointsLocal~items<>tank~cellCount then do; say 'FAIL 2D surface point count'; exit 1; end
if slosh~fundamentalPeriodX<=slosh~fundamentalPeriodZ then do; say 'FAIL 2D natural periods do not follow tank dimensions'; exit 1; end
say 'PHYSICS FREE-SURFACE 2D MASS: OK volume='slosh~currentVolume 'range='slosh~surfaceRange
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'FreeSurfaceFluids2D.cls'
