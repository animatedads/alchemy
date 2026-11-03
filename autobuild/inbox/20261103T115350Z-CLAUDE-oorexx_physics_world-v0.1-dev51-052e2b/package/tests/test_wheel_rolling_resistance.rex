w=.WheelTyreState~new(.5,10,.ConstantRollingResistance~new(.02),.EnergyProportionalWearLaw~new(0),20)
o=w~step(1,10,1000,0)
if o~rollingResistance<>20 | o~energyIncrement<>200 then exit 1
say 'PHYSICS ROLLING RESISTANCE: OK force=' o~rollingResistance 'energy=' o~energyIncrement
::requires 'WheelTyreDynamics.cls'
