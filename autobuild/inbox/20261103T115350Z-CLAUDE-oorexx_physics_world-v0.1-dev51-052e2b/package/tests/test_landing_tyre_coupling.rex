numeric digits 30
w=.WheelTyreState~new(.5,10,.ConstantRollingResistance~new(.01),.EnergyProportionalWearLaw~new(.000000001))
s=.LinearLandingStrut~new(1000000,100000,.5)
g=.LandingGearState~new(10000,s,w,1,.05)
o=g~step(.01,70,.8,0)
if o~normalLoad<=0 | o~tyre~slipSpeed<=0 | o~tyre~dissipatedPower<=0 then exit 1
say 'PHYSICS LANDING TYRE COUPLING: OK load=' o~normalLoad 'slip=' o~tyre~slipSpeed 'power=' o~tyre~dissipatedPower
::requires 'LandingGearDynamics.cls'
