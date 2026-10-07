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
o=e~step(.1,.1,-2,10)
s=o~stations
if s[1]~normalLoad<>240000 | s[2]~normalLoad<>180000 | s[3]~normalLoad<>180000 then exit 1
if o~groundSpeed<>69.8 then exit 1
say 'PHYSICS DYNAMIC GROUND BRAKING LOADS: OK nose=' s[1]~normalLoad 'mainL=' s[2]~normalLoad 'mainR=' s[3]~normalLoad 'speed=' o~groundSpeed
::requires 'AircraftDynamicGroundRun.cls'
