numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)
e=.AcousticEmissionSpectrum~new;e~addBand(.AcousticEmissionBand~new(1000,0.001))
receivers=.directory~new;receivers['FC']=.MathVector3~new(10,0,0,ctx)
u=solver~firstArrivalUncertainty(.MathVector3~new(0,0,0,ctx),.MathVector3~new(1,0,0,ctx),e,receivers,340,350,0.15)
i=u['FC']
if i==.nil then exit 1
if abs(i~minimum-(9/350))>1E-9 then do;say 'FAIL uncertainty min' i~minimum;exit 1;end
if abs(i~maximum-(10/340))>1E-9 then do;say 'FAIL uncertainty max' i~maximum;exit 1;end
say 'PHYSICS ACOUSTIC IMPULSE UNCERTAINTY: OK interval='i~minimum i~maximum
::requires 'AcousticImpulseResponse.cls'
