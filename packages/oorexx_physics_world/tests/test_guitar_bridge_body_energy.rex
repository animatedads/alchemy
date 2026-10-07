numeric digits 30
ctx=.Maths~defaultContext
string=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,8)
modes=.array~new
modes~append(.GuitarBodyMode~new('top-110',110,0.18,0.035,0.045,1.0))
modes~append(.GuitarBodyMode~new('top-220',220,0.12,0.045,0.030,0.6))
bridge=.GuitarBridgeCoupling~new('bridge',0.08,modes,.MathVector3~new(0,0,0,ctx))
x=bridge~exciteFromString(string,0,.0008,.18,'PICK',0,0)
if x~stringInitialEnergy<=0 then exit 1
if abs(x~transferredEnergy/x~stringInitialEnergy-0.08)>1E-6 then exit 1
if abs(x~energyResidual)>1E-12 then exit 1
if x~responses~items<>2 then exit 1
if x~retainedStringEnergy<=x~transferredEnergy then exit 1
say 'PHYSICS GUITAR BRIDGE/BODY ENERGY: OK stringJ=' x~stringInitialEnergy 'bodyJ=' x~allocatedBodyEnergy
::requires 'GuitarStructuralCoupling.cls'
::requires 'MathsBootstrap.cls'
