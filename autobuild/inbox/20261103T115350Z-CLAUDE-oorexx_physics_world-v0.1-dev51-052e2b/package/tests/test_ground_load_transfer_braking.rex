numeric digits 30
g=.LongitudinalGearGeometry~new(4,-2,2)
m=.LongitudinalLoadTransferModel~new(g)
s=m~resolve(60000,0,10); b=m~resolve(60000,-2,10)
if b~noseLoad<=s~noseLoad | b~mainLoad>=s~mainLoad then exit 1
if b~noseLoad<>240000 | b~mainLoad<>360000 then exit 1
say 'PHYSICS GROUND LOAD TRANSFER BRAKING: OK nose=' b~noseLoad 'main=' b~mainLoad
::requires 'AircraftGroundLoadTransfer.cls'
