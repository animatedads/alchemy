numeric digits 30
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
world=.PhysicalWorld~new
body=.PhysicalBody~new('body',.SphereShape~new(.01),.PhysicalPose~identity(ctx))
rb=.RigidBodyState~new(body,.MechanicsMassProperties~pointMass(1,.01))
fails=0
call expectFail 1
patch=.RigidRadiatingPatch~new('patch',rb,zero,.MathVector3~new(1,0,0,ctx),.Units~q(.01,.Units~squareMetre))
patch~observe(.Units~q(0,.Units~second))
rb~velocity=.MathVector3~new(1,0,0,ctx)
patch~observe(.Units~q(.001,.Units~second))
call expectFail 2
call expectFail 3
if fails<>3 then do; say 'FAIL: expected 3 fail-closed driven acoustic cases, got' fails; exit 1; end
say 'PHYSICS DRIVEN ACOUSTIC FAIL-CLOSED: OK'
exit 0
expectFail: procedure expose fails rb zero patch world ctx
  use arg which
  signal on syntax name caught
  select
    when which=1 then bad=.RigidRadiatingPatch~new('bad',rb,zero,.MathVector3~new(1,0,0,ctx),.Units~q(1,.Units~metre))
    when which=2 then patch~observe(.Units~q(.001,.Units~second))
    when which=3 then do
      solver=.AcousticSolver~new(world)
      mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
      p=.ContinuousMechanicalAcousticRenderer~pressureAt(patch,solver,mic,.Units~q('.0039137529137529137529',.Units~second),.Units~q(2,.Units~metre))
    end
    otherwise nop
  end
  say 'FAIL: expected failure case' which
  exit 1
caught:
  fails=fails+1
  return
::requires 'DrivenAcoustics.cls'
