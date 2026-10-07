numeric digits 30
ctx=.Maths~defaultContext
signal on syntax name wrongCurrent
bad=.ElectricalDriveObservation~new(.Units~q(0,.Units~second),.Units~q(1,.Units~metre))
signal off syntax
say 'FAIL: length accepted as electrical current'
exit 1
wrongCurrent:
  signal off syntax
  body=.PhysicalBody~new('armature',.SphereShape~new(.05),.PhysicalPose~identity(ctx))
  rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(1,.05))
  signal on syntax name wrongConstant
  act=.LinearElectromechanicalTransducer~new('bad',rb,.MathVector3~new(0,0,0,ctx),.PhysicalPose~identity(ctx),.MathVector3~new(1,0,0,ctx),.Units~q(2,.Units~volt))
  signal off syntax
  say 'FAIL: volts accepted as force constant'
  exit 1
wrongConstant:
  signal off syntax
  signal on syntax name anonymousCurrent
  bad2=.ElectricalDriveObservation~new(.Units~q(0,.Units~second),1)
  signal off syntax
  say 'FAIL: anonymous scalar accepted at electrical boundary'
  exit 1
anonymousCurrent:
  signal off syntax
  say 'PHYSICS ELECTROMECHANICAL FAIL-CLOSED: OK'
  exit 0
::requires 'Electromechanics.cls'
