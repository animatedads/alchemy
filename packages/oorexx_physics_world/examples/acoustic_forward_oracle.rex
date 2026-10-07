numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)
spectrum=.AcousticEmissionSpectrum~new
do f over .array~of(125,250,500,1000,2000,4000)
  spectrum~addBand(.AcousticEmissionBand~new(f,0.001))
end
receivers=.directory~new
receivers['MIC-A']=.MathVector3~new(0,0,1.5,ctx)
receivers['MIC-B']=.MathVector3~new(8,0,1.5,ctx)
points=.array~new
points~append(.MathVector3~new(2,3,1.5,ctx))
points~append(.MathVector3~new(4,3,1.5,ctx))
predictions=.AcousticForwardOracle~new(solver)~predict(points,spectrum,receivers,0.150)
do p over predictions
  say 'source' p~position~x p~position~y 'MIC-B minus MIC-A seconds='p~firstArrivalDifference('MIC-B','MIC-A')
end
::requires 'AcousticImpulseResponse.cls'
