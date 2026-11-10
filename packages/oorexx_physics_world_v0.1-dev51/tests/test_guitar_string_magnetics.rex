numeric digits 30
string=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,8)
geom=.MagneticFluxGeometry~new(0.000001,0.00012,.82,'fixture-gradient')
probe=.GuitarStringMagneticFluxProbe~new(string,geom)
a=probe~observe(0,0)
b=probe~observe(0,0.0001)
if a~fluxWebers=b~fluxWebers then exit 1
if a~evidence['MODEL']<>'LINEARIZED_LOCAL_FLUX_GRADIENT' then exit 1
if abs(string~frequencyForFret(12)-2*string~openFrequency)>1E-6 then exit 1
vel=b~stringVelocity
say 'PHYSICS GUITAR STRING MAGNETICS: OK flux=' a~fluxWebers b~fluxWebers 'velocity=' vel
::requires 'GuitarStringMagnetics.cls'
