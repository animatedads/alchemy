numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
freq=.array~of(500,1000)
mat=.AcousticSpectralMaterial~new('partition')
mat~addBand(.AcousticBandTransfer~new(500,0.2,0.5,0))
mat~addBand(.AcousticBandTransfer~new(1000,0.3,0.25,0))
wallBody=.PhysicalBody~new('wall',.RectangleShape~new(4,4),.PhysicalPose~identity(ctx))
wall=.AcousticSpectralSurface~new('partition-1',.AcousticSurface~new(wallBody,.AcousticSurfaceMaterial~rigid),mat)
solver=.AcousticImpulseResponseSolver~new(world);solver~addSurface(wall)
e=.AcousticEmissionSpectrum~new
e~addBand(.AcousticEmissionBand~new(500,0.001))
e~addBand(.AcousticEmissionBand~new(1000,0.001))
receivers=.directory~new;receivers['R']=.MathVector3~new(0,0,1,ctx)
r=solver~solve(.MathVector3~new(0,0,-1,ctx),e,receivers,0.15)
a=r~receiver('R')~firstArrival
if a==.nil then exit 1
if a~kind<>'DIRECT_OR_TRANSMITTED' then exit 1
if abs(a~distance-2)>1E-20 then exit 1
ratio=a~phasorAt(1000)~magnitude/a~phasorAt(500)~magnitude
if abs(ratio-0.5)>1E-12 then do;say 'FAIL spectral transmission ratio' ratio;exit 1;end
say 'PHYSICS ACOUSTIC IMPULSE SPECTRAL TRANSMISSION: OK delay='a~delay 'ratio='ratio
::requires 'AcousticImpulseResponse.cls'
