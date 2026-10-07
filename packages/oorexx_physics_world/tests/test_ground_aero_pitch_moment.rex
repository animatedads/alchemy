numeric digits 30
m=.LongitudinalGroundAerodynamicLoadModel~new(.LongitudinalGroundAeroGeometry~new(4,-2))
o=m~resolve(60000,0,0,60000,2,10)
if o~noseLoad<>190000 | o~mainLoad<>410000 then exit 1
say 'PHYSICS GROUND AERO PITCH MOMENT: OK nose=' o~noseLoad 'main=' o~mainLoad
::requires 'AircraftGroundAerodynamicLoading.cls'
