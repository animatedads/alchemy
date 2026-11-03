numeric digits 30
water=.FluidMedium~water20C
load=.ContainedFluidLoad~filledCylinderByVolume(water,.Units~q(3,.Units~centimetre),.Units~q(250,.Units~millilitre))
call near load~volumeQuantity~in(.Units~millilitre),250,'contained liquid volume','0.000001'
call near load~mass,'0.24955','250 mL development-water mass','0.0000001'
if load~height<=0 then do; say 'FAIL contained fluid height'; exit 1; end
dry=.MechanicsMassProperties~hollowCylinder(.22,.027,.031,.10)
wet=load~combineCenteredAligned(dry)
call near wet~mass,.22+load~mass,'combined vessel mass','0.0000001'
if wet~ix<=dry~ix | wet~iy<=dry~iy | wet~iz<=dry~iz then do; say 'FAIL liquid did not increase vessel inertia'; exit 1; end
say 'PHYSICS CONTAINED FLUID LOAD: OK mass='load~mass 'height='load~height
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'VesselDynamics.cls'
