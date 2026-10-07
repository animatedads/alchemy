numeric digits 30
ctx=.MathContext~decimal(30,'PURE')
string=.GuitarStringPhysicalModel~new(82.4068892)
geom=.MagneticFluxGeometry~new(.000001,.00012,.82,'fixture')
renderer=.GuitarMathsModalRenderer~new(string,ctx)
block=renderer~renderPickupFlux(0,geom,48000,48,0)
if block~fluxSamples~items<>48 then exit 1
if block~evidence~operation<>'signal.oscillator-bank' then exit 1
do i=1 to 48
 expected=geom~baselineFlux+geom~fluxDisplacementGradient*block~displacementVector[i]
 if abs(block~fluxSamples[i]-expected)>1E-12 then exit 1
end
say 'PHYSICS GUITAR MATHS10 FLUX BLOCK: OK samples=' block~fluxSamples~items
::requires 'GuitarMathsAcceleration.cls'
