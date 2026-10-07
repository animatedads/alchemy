numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
tank=.PhysicalMediumRegion~new('tank',.BoxShape~new(1,1,1,ctx),.OpticalMedium~water,.AcousticMedium~water,.PhysicalPose~identity(ctx),10)
world~addMediumRegion(tank)
source=.AcousticToneSource~new('speaker',1000,'0.001',.PhysicalPose~new(.MathVector3~new(0,0,'-0.75',ctx),.nil,ctx))
mic=.AcousticMicrophone~new('hydrophone',.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx),'0.000001')
solver=.AcousticSolver~new(world); solver~addSource(source); solver~addMicrophone(mic)
call expectMixedMediaFailure solver
say 'PHYSICS ACOUSTICS MIXED-MEDIA FAIL-CLOSED: OK'
exit 0
expectMixedMediaFailure: procedure
  use strict arg solver
  signal on syntax name expected
  solver~solveTone(1000)
  say 'FAIL mixed air-water path was silently approximated'; exit 1
expected:
  return
::requires 'Acoustics.cls'
