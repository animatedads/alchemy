numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
pose=.PhysicalPose~new(.MathVector3~new(0,'0.15',0,ctx),.nil,ctx)
body=.OpticalBody~new('body',.SphereShape~new('0.1'),.nil,pose)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(1,'0.1'),.MathVector3~new(0,-1,0,ctx),.nil,.false,0,'0.1')
plane=.CollisionPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),0)
solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx)); solver~addBody(state); solver~addPlane(plane); solver~step('0.1')

a=.Units~q(100,.Units~centimetre~power(2))
mode1=.StructuralVibrationMode~new('m1',state,.MathVector3~new(0,'-0.1',0,ctx),.MathVector3~new(0,1,0,ctx),1,1000,'0.02',a)
mode2=.StructuralVibrationMode~new('m2',state,.MathVector3~new(0,'-0.1',0,ctx),.MathVector3~new(0,1,0,ctx),1,1200,'0.02',a)
c=.StructuralAcousticCoupler~new; c~addMode(mode1); c~addMode(mode2)
signal on syntax name expected
c~consumeMechanicsStep(solver)
say 'FAIL over-budget modal excitation was accepted'
exit 1
expected:
  signal off syntax
  say 'PHYSICS MECHANICAL -> ACOUSTIC ENERGY GUARD: OK'
  exit 0
::requires 'MechanicalAcoustics.cls'
