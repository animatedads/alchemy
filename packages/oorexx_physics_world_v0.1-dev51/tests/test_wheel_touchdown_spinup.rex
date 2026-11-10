numeric digits 30
w=.WheelTyreState~new(.5,10,.ConstantRollingResistance~new(0),.EnergyProportionalWearLaw~new(0))
before=w~slipSpeed(70); o=w~step(.01,70,100000,.8); after=w~slipSpeed(70)
if before<>70 | after>=before | o~dissipatedPower<=0 then exit 1
say 'PHYSICS TYRE TOUCHDOWN SPINUP: OK slipBefore=' before 'slipAfter=' after 'power=' o~dissipatedPower
::requires 'WheelTyreDynamics.cls'
