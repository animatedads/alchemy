numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
mat=.AcousticSpectralMaterial~new('rigid-wall');mat~addBand(.AcousticBandTransfer~new(1000,1,0,0))
wallBody=.PhysicalBody~new('wall',.RectangleShape~new(6,6),.PhysicalPose~identity(ctx))
wall=.AcousticSpectralSurface~new('wall',.AcousticSurface~new(wallBody,.AcousticSurfaceMaterial~rigid),mat)
edgeMat=.AcousticSpectralMaterial~new('door-edge-evidence');edgeMat~addBand(.AcousticBandTransfer~new(1000,0,0,0.4))
solver=.AcousticImpulseResponseSolver~new(world);solver~addSurface(wall)
solver~addDiffractionPoint(.AcousticDiffractionPoint~new('door-corner',.MathVector3~new(0,2.9,0,ctx),edgeMat))
e=.AcousticEmissionSpectrum~new;e~addBand(.AcousticEmissionBand~new(1000,0.001))
receivers=.directory~new;receivers['FD']=.MathVector3~new(1,0,1,ctx)
r=solver~solve(.MathVector3~new(-1,0,-1,ctx),e,receivers,0.15)
arr=r~receiver('FD')~arrivals
if arr~items<>1 then do;say 'FAIL expected only admitted diffraction path' arr~items;exit 1;end
a=arr[1]
if a~kind<>'DIFFRACTION' then exit 1
if a~vertices~items<>3 then exit 1
if a~vertices[2]~name<>'door-corner' then exit 1
say 'PHYSICS ACOUSTIC IMPULSE BOUNDED DIFFRACTION: OK delay='a~delay 'distance='a~distance
::requires 'AcousticImpulseResponse.cls'
