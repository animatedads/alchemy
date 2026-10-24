/* NOT YET EXECUTED under a real interpreter in the delivery environment --
 * see accompanying message. Structured as a direct parallel to
 * test_guitar_six_string_sympathetic.rex: energy starts at zero on an
 * unplucked course, rises only through boundary coupling, and the plucked
 * course itself carries positive energy throughout. */
numeric digits 30
models=.BassInstrumentFactory~standardStringSet
frets=.array~of(0,0,0,0)
body=.BassInstrumentFactory~standardBodyModes
bridge=.BassInstrumentFactory~standardBridgeImpedance
nut=.BassInstrumentFactory~standardNutImpedance
b=.BassInstrumentFactory~standardFourStringBass(models,frets,body,bridge,nut,1,.0014,.20)
silent0=b~course('G2')~mechanicalEnergy
maxSilent=silent0
initial=b~totalMechanicalEnergy
do i=1 to 1200
 b~step(.0000025)
 e=b~course('G2')~mechanicalEnergy
 if e>maxSilent then maxSilent=e
end
if silent0<>0 then exit 1
if maxSilent<=0 then exit 1
if b~course('E1')~mechanicalEnergy<=0 then exit 1
say 'PHYSICS BASS FOUR-STRING SYMPATHETIC: OK initialJ=' initial 'silentG2maxJ=' maxSilent
::requires 'BassGuitarMechanics.cls'
