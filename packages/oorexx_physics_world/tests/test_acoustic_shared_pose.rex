numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
body=.PhysicalBody~new('moving-speaker',.SphereShape~new('0.05'),.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
world~addBody(body)
state=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(1,'0.05'),.MathVector3~new(1,0,0,ctx))
mechanics=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx)); mechanics~addBody(state)
source=.AcousticToneSource~onBody('speaker',body,.MathVector3~new(0,0,0,ctx),500,'0.001')
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(3,0,0,ctx),.nil,ctx))
a=.AcousticSolver~new(world); a~addSource(source); a~addMicrophone(mic); a~solveTone(500)
pBefore=mic~readingAt(500)~pressureRms
mechanics~step(1)
call near body~pose~position~x,1,'mechanics updated authoritative body pose','0.00000001'
mic~reset; a~solveTone(500)
pAfter=mic~readingAt(500)~pressureRms
/* Source moved from 3 m to 2 m from microphone; spherical pressure scales 1/r. */
call near pAfter/pBefore,'1.5','acoustics observed mechanics-moved source','0.000001'
say 'PHYSICS ACOUSTICS + MECHANICS SHARED POSE: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
::requires 'Mechanics.cls'
