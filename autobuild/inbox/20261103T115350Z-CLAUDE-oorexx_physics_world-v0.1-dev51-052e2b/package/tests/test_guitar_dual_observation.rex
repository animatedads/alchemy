numeric digits 30
ctx=.Maths~defaultContext
string=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,8)
geom=.MagneticFluxGeometry~new(0.000001,0.00012,.82,'fixture-gradient')
fluxProbe=.GuitarStringMagneticFluxProbe~new(string,geom)
modes=.array~of(.GuitarBodyMode~new('body-170',170,0.20,0.04,0.05,1))
bridge=.GuitarBridgeCoupling~new('bridge',0.05,modes,.MathVector3~new(0,0,0,ctx))
p0=fluxProbe~observe(0,0)
p1=fluxProbe~observe(0,0.0001)
body=bridge~exciteFromString(string,0,.0008,.18,'PICK',0,0)
if p0~fluxWebers=p1~fluxWebers then exit 1
if body~responses[1]~initialMechanicalEnergy<=0 then exit 1
if body~responses[1]~volumeAccelerationAfter(.001)=0 then exit 1
say 'PHYSICS GUITAR DUAL OBSERVATION: OK fluxDelta=' p1~fluxWebers-p0~fluxWebers 'bodyJ=' body~allocatedBodyEnergy
::requires 'GuitarStructuralCoupling.cls'
::requires 'MathsBootstrap.cls'
