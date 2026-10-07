numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)
e=.AcousticEmissionSpectrum~new;e~addBand(.AcousticEmissionBand~new(1000,0.001))
receivers=.directory~new
receivers['FC']=.MathVector3~new(10,0,0,ctx)
receivers['FD']=.MathVector3~new(0,10,0,ctx)
points=.array~new;points~append(.MathVector3~new(2,0,0,ctx));points~append(.MathVector3~new(0,2,0,ctx))
pred=.AcousticForwardOracle~new(solver)~predict(points,e,receivers,0.15)
if pred~items<>2 then exit 1
d1=pred[1]~firstArrivalDifference('FD','FC')
d2=pred[2]~firstArrivalDifference('FD','FC')
if d1<=0 then do;say 'FAIL expected FD later for first point' d1;exit 1;end
if d2>=0 then do;say 'FAIL expected FD earlier for second point' d2;exit 1;end
if pred[1]~energyRatio('FD','FC')>=1 then exit 1
say 'PHYSICS ACOUSTIC FORWARD ORACLE PAIR: OK tdoa='d1 d2
::requires 'AcousticImpulseResponse.cls'
