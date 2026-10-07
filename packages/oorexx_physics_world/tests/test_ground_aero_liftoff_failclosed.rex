m=.LongitudinalGroundAerodynamicLoadModel~new(.LongitudinalGroundAeroGeometry~new(4,-2))
signal on syntax name bad
o=m~resolve(60000,0,700000,0,2,10)
exit 1
bad:
say 'PHYSICS GROUND AERO LIFTOFF FAIL-CLOSED: OK'
exit 0
::requires 'AircraftGroundAerodynamicLoading.cls'
