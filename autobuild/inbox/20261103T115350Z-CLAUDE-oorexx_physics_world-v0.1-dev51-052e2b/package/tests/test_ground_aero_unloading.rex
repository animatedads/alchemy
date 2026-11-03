numeric digits 30
m=.LongitudinalGroundAerodynamicLoadModel~new(.LongitudinalGroundAeroGeometry~new(4,-2))
o=m~resolve(60000,0,120000,0,2,10)
if o~totalGroundLoad<>480000 | o~noseLoad<>160000 | o~mainLoad<>320000 then exit 1
say 'PHYSICS GROUND AERO UNLOADING: OK total=' o~totalGroundLoad 'nose=' o~noseLoad 'main=' o~mainLoad
::requires 'AircraftGroundAerodynamicLoading.cls'
