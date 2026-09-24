numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(.6,.4,.3,12,8)
slosh=.RectangularTankSlosh2D~new(water,tank,.036,.04)

do n=1 to 250
  slosh~step(.0015,-1.5,.8)
end
com=slosh~centreOfMassLocal
if com~x>=-.0001 then do; say 'FAIL 2D x forcing COM direction' com~x; exit 1; end
if com~z<=.00005 then do; say 'FAIL 2D z forcing COM direction' com~z; exit 1; end
if slosh~surfaceRange<=.0001 then do; say 'FAIL 2D forcing produced no surface displacement'; exit 1; end
snap=slosh~snapshot
call near snap~gravityX,-1.5,'snapshot x effective gravity','0.000000001'
call near snap~gravityZ,.8,'snapshot z effective gravity','0.000000001'
say 'PHYSICS FREE-SURFACE 2D FORCING: OK xCOM='com~x 'zCOM='com~z 'range='slosh~surfaceRange
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'FreeSurfaceFluids2D.cls'
