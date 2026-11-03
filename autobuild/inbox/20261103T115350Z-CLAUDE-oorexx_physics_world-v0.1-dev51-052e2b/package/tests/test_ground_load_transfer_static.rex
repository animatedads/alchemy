numeric digits 30
g=.LongitudinalGearGeometry~new(4,-2,2)
m=.LongitudinalLoadTransferModel~new(g)
o=m~resolve(60000,0,10)
if o~noseLoad<>200000 | o~mainLoad<>400000 then exit 1
say 'PHYSICS GROUND LOAD TRANSFER STATIC: OK nose=' o~noseLoad 'main=' o~mainLoad
::requires 'AircraftGroundLoadTransfer.cls'
