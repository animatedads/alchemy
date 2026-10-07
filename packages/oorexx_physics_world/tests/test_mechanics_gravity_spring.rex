numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
fallBody=.OpticalBody~new('falling',.SphereShape~new('0.1'),.nil,.PhysicalPose~new(.MathVector3~new(0,10,0,ctx),.nil,ctx))
fall=.RigidBodyState~new(fallBody,.MechanicsMassProperties~solidSphere(1,'0.1'))
solver=.MechanicsSolver~new(world)
solver~addBody(fall)
do 1000; solver~step('0.001'); end
call near fall~velocity~y,'-9.80665','free-fall velocity','0.000001'
/* Symplectic Euler is lower than the exact position by roughly g*dt/2. */
call near fall~position~y,'5.091771675','free-fall position','0.00001'

anchorBody=.OpticalBody~new('anchor',.SphereShape~new('0.05'),.nil,.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
massBody=.OpticalBody~new('spring-mass',.SphereShape~new('0.05'),.nil,.PhysicalPose~new(.MathVector3~new(2,0,0,ctx),.nil,ctx))
anchor=.RigidBodyState~new(anchorBody,.MechanicsMassProperties~solidSphere(1,'0.05'),.nil,.nil,.true)
mass=.RigidBodyState~new(massBody,.MechanicsMassProperties~solidSphere(1,'0.05'))
s=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
s~addBody(anchor); s~addBody(mass)
s~addSpring(.SpringConstraint~new(anchor,mass,1,10,0))
s~step('0.1')
/* Extension=1 m, spring force on moving mass=-10 N. */
call near mass~velocity~x,-1,'Hooke spring velocity','0.000001'
call near mass~position~x,'1.9','Hooke spring position','0.000001'
say 'PHYSICS MECHANICS GRAVITY + SPRING: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Mechanics.cls'
