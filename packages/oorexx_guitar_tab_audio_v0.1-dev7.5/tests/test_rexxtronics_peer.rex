/* Full electrical peer smoke. Run only after check_rexxtronics_peer.sh admits source. */
numeric digits 30
neck=.GuitarMagneticPickup~new('NECK',800,.Units~q(5800,.Units~ohm),.Units~q(2.2,.Units~henry),.Units~q(85E-12,.Units~farad))
bridge=.GuitarMagneticPickup~new('BRIDGE',800,.Units~q(6400,.Units~ohm),.Units~q(2.6,.Units~henry),.Units~q(95E-12,.Units~farad))
selector=.GuitarPickupSelector~new('BOTH')
net=.GuitarLoadedNetwork~new(.Units~q(500000,.Units~ohm),.Units~q(500000,.Units~ohm),.Units~q(22E-9,.Units~farad),.Units~q(470E-12,.Units~farad),.Units~q(1000000,.Units~ohm),.92,.82)
out=net~outputMagnitudeForSelector(selector,neck,.001,bridge,.001,.Units~q(440,.Units~hertz))
if datatype(out,'N')=0 then do; say 'FAIL Rexx-tronics guitar peer output'; exit 1; end
say 'PASS dev7.5 Rexx-tronics guitar electrical peer'
exit 0
::requires 'RexxTronicsGuitar.cls'
