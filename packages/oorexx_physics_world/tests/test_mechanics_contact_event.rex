numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
pose=.PhysicalPose~new(.MathVector3~new(0,'0.15',0,ctx),.nil,ctx)
body=.OpticalBody~new('ball',.SphereShape~new('0.1'),.nil,pose)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(1,'0.1'),.MathVector3~new(0,-1,0,ctx),.nil,.false,0,'0.1')
plane=.CollisionPlane~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),0)
solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
solver~addBody(state); solver~addPlane(plane)
solver~step(.Units~q(100,.Units~millisecond))
events=solver~contactEvents
if events~items<>1 then do; say 'FAIL contact event count' events~items; exit 1; end
e=events[1]
if e~kind<>'PLANE' then do; say 'FAIL contact kind' e~kind; exit 1; end
call near e~impulseMagnitude,1,'normal impulse N*s','0.000000001'
call near e~impulseOnA~y,1,'impulse vector y','0.000000001'
call near e~dissipatedEnergy,'0.5','dissipated collision energy','0.000000001'
call near e~time,'0.1','event time','0.000000001'
call near e~point~y,0,'contact point plane','0.000000001'
if \e~impulseMagnitudeQuantity~dimension~compatible(.Units~newtonSecond~dimension) then do; say 'FAIL impulse dimension'; exit 1; end
if \e~dissipatedEnergyQuantity~dimension~compatible(.Units~joule~dimension) then do; say 'FAIL energy dimension'; exit 1; end
say 'PHYSICS MECHANICS CONTACT EVENT: OK impulse='e~impulseMagnitude 'N*s energy='e~dissipatedEnergy 'J'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label 'actual='actual 'expected='expected; exit 1; end
return
::requires 'MechanicalAcoustics.cls'
