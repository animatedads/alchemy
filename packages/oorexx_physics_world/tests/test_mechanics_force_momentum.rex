numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
body=.OpticalBody~new('mass',.SphereShape~new('0.5'),.nil,.PhysicalPose~identity(ctx))
world~addBody(body)
rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(2,'0.5'))
solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
solver~addBody(rb)
rb~applyForce(.MathVector3~new(10,0,0,ctx))
solver~step(1)
call near rb~velocity~x,5,'force acceleration velocity'
call near rb~position~x,5,'force integration position'
call near rb~momentum~x,10,'linear momentum'
call near rb~kineticEnergy,25,'kinetic energy'
rb~applyImpulse(.MathVector3~new(-4,6,0,ctx))
call near rb~velocity~x,3,'impulse x velocity'
call near rb~velocity~y,3,'impulse y velocity'
call near rb~momentum~y,6,'impulse momentum'
angle=.MechanicsKinematics~directionDegreesXY(rb~velocity)
call near angle,45,'movement heading'
say 'PHYSICS MECHANICS FORCE + MOMENTUM: OK'
exit 0
near: procedure
  use arg actual,expected,label
  if abs(actual-expected)>'0.000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Mechanics.cls'
