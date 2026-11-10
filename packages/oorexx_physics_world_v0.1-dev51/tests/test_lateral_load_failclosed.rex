m=.LateralAxleLoadTransferModel~new(.LateralAxleGeometry~new(2,3))
signal on syntax name bad
o=m~resolve(100000,20,10)
exit 1
bad:
say 'PHYSICS LATERAL LOAD FAIL-CLOSED: OK'
exit 0
::requires 'AircraftLateralLoadTransfer.cls'
