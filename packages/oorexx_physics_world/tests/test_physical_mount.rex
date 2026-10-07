numeric digits 20
ctx=.Maths~defaultContext
parent=.OpticalBody~new('parent',.BoxShape~new(1,1,1,ctx),.nil, -
  .PhysicalPose~new(.MathVector3~new(10,0,0,ctx),.nil,ctx))
mount=.PhysicalMount~new(parent,.PhysicalPose~new(.MathVector3~new(2,3,4,ctx),.nil,ctx))
p=mount~position
call near p~x,12,'mount x'
call near p~y,3,'mount y'
call near p~z,4,'mount z'
parent~pose=.PhysicalPose~new(.MathVector3~new(20,0,0,ctx),.nil,ctx)
p=mount~position
call near p~x,22,'live mount follows parent'
say 'PHYSICS PHYSICAL MOUNT: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Coupling.cls'
