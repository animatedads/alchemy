rr=.ConstantRollingResistance~new(0); wear=.EnergyProportionalWearLaw~new(0)
a=.array~new
a~append(.DynamicGroundTyreStation~new('NOSE','NOSE',1,.WheelTyreState~new(.5,10,rr,wear)))
a~append(.DynamicGroundTyreStation~new('MAIN-L','MAIN',.7,.WheelTyreState~new(.5,10,rr,wear)))
loads=.LongitudinalLoadTransferModel~new(.LongitudinalGearGeometry~new(4,-2,2))
signal on syntax name bad
e=.DynamicAircraftGroundExperiment~new(60000,70,a,loads)
exit 1
bad:
say 'PHYSICS DYNAMIC GROUND AXLE SHARES FAIL-CLOSED: OK'
exit 0
::requires 'AircraftDynamicGroundRun.cls'
