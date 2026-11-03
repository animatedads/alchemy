numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
body=.OpticalBody~new('rotor',.SphereShape~new('0.5'),.nil,.PhysicalPose~identity(ctx))
rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(2,'0.5'),.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,0,'3.14159265358979323846',ctx),.false,1,'0.5')
solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
solver~addBody(rb)
solver~step('0.5')
call near rb~orientation~w,'0.7071067811865475','90deg quaternion w','0.000001'
call near rb~orientation~z,'0.7071067811865475','90deg quaternion z','0.000001'

/* Perfectly elastic plane collision: sphere penetrates slightly then is projected out and velocity reverses. */
ballBody=.OpticalBody~new('ball',.SphereShape~new('0.5'),.nil,.PhysicalPose~new(.MathVector3~new(0,'0.55',0,ctx),.nil,ctx))
ball=.RigidBodyState~new(ballBody,.MechanicsMassProperties~solidSphere(1,'0.5'),.MathVector3~new(0,-1,0,ctx),.nil,.false,1,'0.5')
c=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
c~addBody(ball)
c~addPlane(.CollisionPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),1))
c~step('0.1')
call near ball~position~y,'0.5','plane penetration correction','0.000001'
call near ball~velocity~y,1,'elastic plane bounce','0.000001'
say 'PHYSICS MECHANICS ROTATION + COLLISION: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Mechanics.cls'
