numeric digits 30
long=.LongitudinalLoadTransferModel~new(.LongitudinalGearGeometry~new(4,-2,2))
nose=.LateralAxleLoadTransferModel~new(.LateralAxleGeometry~new(4,2))
main=.LateralAxleLoadTransferModel~new(.LateralAxleGeometry~new(6,2))
m=.AircraftCombinedGroundLoadModel~new(long,nose,main)
o=m~resolve(60000,-2,2,10)
if o~noseLeft<>144000 | o~noseRight<>96000 then exit 1
if o~mainLeft<>204000 | o~mainRight<>156000 then exit 1
if o~totalLoad<>600000 then exit 1
say 'PHYSICS COMBINED GROUND LOADS: OK NL=' o~noseLeft 'NR=' o~noseRight 'ML=' o~mainLeft 'MR=' o~mainRight
::requires 'AircraftCombinedGroundLoads.cls'
