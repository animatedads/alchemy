numeric digits 30
m=.LateralAxleLoadTransferModel~new(.LateralAxleGeometry~new(6,2))
o=m~resolve(360000,-2,10)
if o~leftLoad+o~rightLoad<>360000 then exit 1
if o~rightLoad<=o~leftLoad then exit 1
say 'PHYSICS LATERAL LOAD CONSERVATION: OK left=' o~leftLoad 'right=' o~rightLoad
::requires 'AircraftLateralLoadTransfer.cls'
