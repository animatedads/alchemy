numeric digits 30
m=.LateralAxleLoadTransferModel~new(.LateralAxleGeometry~new(6,2))
o=m~resolve(360000,2,10)
if o~leftLoad<>204000 | o~rightLoad<>156000 | o~loadTransfer<>24000 then exit 1
say 'PHYSICS LATERAL LOAD TRANSFER: OK left=' o~leftLoad 'right=' o~rightLoad 'transfer=' o~loadTransfer
::requires 'AircraftLateralLoadTransfer.cls'
