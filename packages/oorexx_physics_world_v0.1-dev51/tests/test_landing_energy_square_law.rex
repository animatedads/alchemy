numeric digits 30
rr=.ConstantRollingResistance~new(0); wear=.EnergyProportionalWearLaw~new(0)
w1=.WheelTyreState~new(.5,10,rr,wear); w2=.WheelTyreState~new(.5,10,rr,wear)
s=.LinearLandingStrut~new(1000000,100000,.5)
a=.LandingGearState~new(10000,s,w1,1); b=.LandingGearState~new(10000,s,w2,2)
if b~verticalKineticEnergy<>4*a~verticalKineticEnergy then exit 1
say 'PHYSICS LANDING ENERGY SQUARE LAW: OK E1=' a~verticalKineticEnergy 'E2=' b~verticalKineticEnergy
::requires 'LandingGearDynamics.cls'
