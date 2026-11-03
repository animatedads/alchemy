numeric digits 30
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
world=.PhysicalWorld~new
body=.PhysicalBody~new('patch-body',.SphereShape~new(.01),.PhysicalPose~identity(ctx))
world~addBody(body)
rb=.RigidBodyState~new(body,.MechanicsMassProperties~pointMass(1,.01),zero,zero)
patch=.RigidRadiatingPatch~new('patch',rb,zero,.MathVector3~new(1,0,0,ctx),.Units~q(.01,.Units~squareMetre))
patch~observe(.Units~q(0,.Units~second))
rb~velocity=.MathVector3~new(1,0,0,ctx)
obs=patch~observe(.Units~q(.001,.Units~second))
call near obs~normalAcceleration,1000,'finite-difference acceleration'
call near obs~volumeAcceleration,10,'volume acceleration'
solver=.AcousticSolver~new(world)
mic1=.AcousticMicrophone~new('one-metre',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
mic2=.AcousticMicrophone~new('two-metre',.PhysicalPose~new(.MathVector3~new(2,0,0,ctx),.nil,ctx))
c=.AcousticMedium~air~soundSpeed
pEarly=.ContinuousMechanicalAcousticRenderer~pressureAt(patch,solver,mic1,.Units~q(.001,.Units~second))
call near pEarly,0,'retarded-time causality'
p1=.ContinuousMechanicalAcousticRenderer~pressureAt(patch,solver,mic1,.Units~q(.001+1/c,.Units~second))
p2=.ContinuousMechanicalAcousticRenderer~pressureAt(patch,solver,mic2,.Units~q(.001+2/c,.Units~second))
if abs(p1)<=.000001 then do; say 'FAIL: one-metre pressure should be non-zero'; exit 1; end
call near p1/p2,2,'inverse-distance pressure ratio','.00001'
if \.ContinuousMechanicalAcousticRenderer~pressureQuantityAt(patch,solver,mic1,.Units~q(.001+1/c,.Units~second))~dimension~compatible(.Units~pascal~dimension) then do
  say 'FAIL: pressure quantity dimension'; exit 1
end
say 'PHYSICS DRIVEN ACOUSTIC PATCH: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'DrivenAcoustics.cls'
