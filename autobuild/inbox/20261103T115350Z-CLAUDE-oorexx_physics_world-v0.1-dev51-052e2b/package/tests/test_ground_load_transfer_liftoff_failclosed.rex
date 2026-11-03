g=.LongitudinalGearGeometry~new(4,-2,2)
m=.LongitudinalLoadTransferModel~new(g)
signal on syntax name bad
x=m~resolve(60000,-25,10)
exit 1
bad:
say 'PHYSICS GROUND LOAD TRANSFER FAIL-CLOSED: OK'
exit 0
::requires 'AircraftGroundLoadTransfer.cls'
