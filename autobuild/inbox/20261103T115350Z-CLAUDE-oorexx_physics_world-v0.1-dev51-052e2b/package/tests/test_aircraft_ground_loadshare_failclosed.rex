stations=.array~new
w=.WheelTyreState~new(.5,10,.ConstantRollingResistance~new(0),.EnergyProportionalWearLaw~new(0))
g=.LandingGearState~new(1000,.LinearLandingStrut~new(1000,100,.5),w,0)
stations~append(.GroundGearStation~new('A',g,.6))
stations~append(.GroundGearStation~new('B',g,.6))
signal on syntax name bad
x=.AircraftGroundExperiment~new(1000,10,stations)
exit 1
bad:
say 'PHYSICS AIRCRAFT LOAD SHARE FAIL-CLOSED: OK'
exit 0
::requires 'AircraftGroundDynamics.cls'
