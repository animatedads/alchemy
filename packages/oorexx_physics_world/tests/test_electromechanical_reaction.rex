numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(1,0,0,ctx)
moverBody=.PhysicalBody~new('mover',.SphereShape~new(.05),.PhysicalPose~new(.MathVector3~new(.2,0,0,ctx),.nil,ctx))
statorBody=.PhysicalBody~new('stator',.SphereShape~new(.05),.PhysicalPose~identity(ctx))
mover=.RigidBodyState~new(moverBody,.MechanicsMassProperties~solidSphere(1,.05))
stator=.RigidBodyState~new(statorBody,.MechanicsMassProperties~solidSphere(1,.05))
world~addBody(moverBody); world~addBody(statorBody)
solver=.MechanicsSolver~new(world,zero)
solver~addBody(mover); solver~addBody(stator)
frame=.PhysicalMount~new(statorBody)
act=.LinearElectromechanicalTransducer~new('reciprocal-pair',mover,zero,frame,axis,.Units~q(2,.Units~newton/.Units~ampere),stator,zero)
drive=.ElectricalDriveObservation~new(.Units~q(0,.Units~second),.Units~q(1,.Units~ampere))
ev=act~applyDrive(drive)
if \ev~reactionApplied then do; say 'FAIL: reaction force not applied'; exit 1; end
solver~step(.Units~q(1,.Units~second))
call near mover~velocity~x,2,'mover reaction velocity'
call near stator~velocity~x,-2,'stator reaction velocity'
call near solver~totalMomentum~x,0,'equal-opposite momentum conservation'
say 'PHYSICS ELECTROMECHANICAL REACTION: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Electromechanics.cls'
