numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)
e=.AcousticEmissionSpectrum~new;e~addBand(.AcousticEmissionBand~new(500,0.001))
receivers=.directory~new;receivers['FD']=.MathVector3~new(10,0,0,ctx)
tr=.AcousticTrajectory~new
tr~add(.AcousticTrajectorySample~new(0,.MathVector3~new(0,0,0,ctx),.MathVector3~new(1,0,0,ctx)))
tr~add(.AcousticTrajectorySample~new(1,.MathVector3~new(1,0,0,ctx),.MathVector3~new(1,0,0,ctx)))
out=solver~solveTrajectory(tr,e,receivers,0.15)
if out~items<>2 then exit 1
a1=out[1]~receiver('FD')~firstArrival;a2=out[2]~receiver('FD')~firstArrival
if a2~distance>=a1~distance then exit 1
if a2~arrivalTime<=1 then exit 1
say 'PHYSICS ACOUSTIC IMPULSE MOVING SOURCE: OK' a1~distance a2~distance
::requires 'AcousticImpulseResponse.cls'
