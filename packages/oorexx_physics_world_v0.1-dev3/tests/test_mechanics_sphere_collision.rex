numeric digits 20
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
pa=.PhysicalPose~new(.MathVector3~new('-0.55',0,0,ctx),.nil,ctx)
pb=.PhysicalPose~new(.MathVector3~new('0.55',0,0,ctx),.nil,ctx)
a=.RigidBodyState~new(.OpticalBody~new('A',.SphereShape~new('0.5'),.nil,pa),.MechanicsMassProperties~solidSphere(1,'0.5'),.MathVector3~new(1,0,0,ctx),.nil,.false,1,'0.5')
b=.RigidBodyState~new(.OpticalBody~new('B',.SphereShape~new('0.5'),.nil,pb),.MechanicsMassProperties~solidSphere(1,'0.5'),.MathVector3~new(-1,0,0,ctx),.nil,.false,1,'0.5')
s=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
s~addBody(a); s~addBody(b)
p0=s~totalMomentum
s~step('0.1')
call near a~velocity~x,-1,'equal-mass elastic A','0.000001'
call near b~velocity~x,1,'equal-mass elastic B','0.000001'
p1=s~totalMomentum
call near p1~x,p0~x,'collision momentum conservation','0.000001'
say 'PHYSICS MECHANICS SPHERE COLLISION: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Mechanics.cls'
