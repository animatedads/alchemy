numeric digits 30
w=.WheelTyreState~new(.5,10,.ConstantRollingResistance~new(0),.EnergyProportionalWearLaw~new(0))
s=.LinearLandingStrut~new(1000000,100000,.5)
g=.LandingGearState~new(10000,s,w,2,.05)
o=g~step(.01,0,0,0)
if o~normalLoad<=0 | o~strutWork<=0 then exit 1
say 'PHYSICS LANDING STRUT DAMPING: OK load=' o~normalLoad 'dampingEnergy=' o~strutWork
::requires 'LandingGearDynamics.cls'
