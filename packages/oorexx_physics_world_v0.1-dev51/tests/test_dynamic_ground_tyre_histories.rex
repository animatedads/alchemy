numeric digits 30
rr=.ConstantRollingResistance~new(.01)
wear=.EnergyProportionalWearLaw~new(.000000001)
n=.WheelTyreState~new(.5,10,rr,wear,140)
l=.WheelTyreState~new(.5,10,rr,wear,140)
r=.WheelTyreState~new(.5,10,rr,wear,140)
a=.array~new
a~append(.DynamicGroundTyreStation~new('NOSE','NOSE',1,n))
a~append(.DynamicGroundTyreStation~new('MAIN-L','MAIN',.5,l))
a~append(.DynamicGroundTyreStation~new('MAIN-R','MAIN',.5,r))
loads=.LongitudinalLoadTransferModel~new(.LongitudinalGearGeometry~new(4,-2,2))
e=.DynamicAircraftGroundExperiment~new(60000,70,a,loads)
o=e~step(.01,.1,-2,10); s=o~stations
if s[1]~tyre~dissipatedPower<=s[2]~tyre~dissipatedPower then exit 1
if s[1]~tyre~totalWear<=s[2]~tyre~totalWear then exit 1
say 'PHYSICS DYNAMIC GROUND TYRE HISTORIES: OK noseWear=' s[1]~tyre~totalWear 'mainWear=' s[2]~tyre~totalWear
::requires 'AircraftDynamicGroundRun.cls'
