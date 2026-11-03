numeric digits 30
w=.WheelTyreState~new(.5,10,.ConstantRollingResistance~new(.01),.EnergyProportionalWearLaw~new(.000001),20)
o=w~step(2,10,1000,0)
if abs(o~totalWear-.0002)>.0000000001 then exit 1
say 'PHYSICS TYRE WEAR FROM DISSIPATION: OK energy=' o~totalEnergy 'wear=' o~totalWear
::requires 'WheelTyreDynamics.cls'
