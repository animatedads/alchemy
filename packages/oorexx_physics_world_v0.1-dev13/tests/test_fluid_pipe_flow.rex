numeric digits 30
water=.FluidMedium~water20C
pipe=.LaminarCircularPipeFlow~new( -
  water, -
  .Units~q(5,.Units~millimetre), -
  .Units~q(1,.Units~metre), -
  .Units~q(10,.Units~pascal))
call near pipe~volumeFlowRate,'0.0000024494703199770716','Hagen-Poiseuille Q','0.0000000000000001'
call near pipe~meanVelocity,'0.031187624750499','mean velocity','0.000000000001'
call near pipe~maximumVelocity,'0.062375249500998','centreline velocity','0.000000000001'
call near pipe~velocityAtRadius(.Units~q('2.5',.Units~millimetre)),'0.0467814371257485','half-radius velocity','0.000000000001'
call near pipe~velocityAtRadius(.Units~q(5,.Units~millimetre)),0,'no-slip wall velocity','0.000000000001'
call near pipe~reynoldsNumber,'310.6934832928953','Reynolds number','0.000000001'
call near pipe~wallShearStress,'0.025','wall shear stress','0.000000001'
if \pipe~laminarWithinReferenceRange then do; say 'FAIL expected laminar reference range'; exit 1; end
pipe~requireLaminar
if \pipe~volumeFlowRateQuantity~dimension~compatible((.Units~cubicMetre/.Units~second)~dimension) then do
  say 'FAIL volumetric flow quantity dimension'; exit 1
end

turbulentEvidence=.LaminarCircularPipeFlow~new(water,'0.005',1,100)
if turbulentEvidence~laminarWithinReferenceRange then do; say 'FAIL high Reynolds should exceed reference range'; exit 1; end
call expectOutsideLaminar turbulentEvidence
say 'PHYSICS FLUID LAMINAR PIPE: OK Re='pipe~reynoldsNumber
exit 0
expectOutsideLaminar: procedure
  use strict arg flow
  signal on syntax name expected
  flow~requireLaminar
  say 'FAIL requireLaminar accepted out-of-range Reynolds'; exit 1
expected:
  return
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Fluids.cls'
