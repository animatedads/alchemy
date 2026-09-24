numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
body=.PhysicalBody~new('armature',.SphereShape~new(.05),.PhysicalPose~identity(ctx))
world~addBody(body)
rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(2,.05))
solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
solver~addBody(rb)
frame=.PhysicalPose~identity(ctx)
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(1,0,0,ctx)
k=.Units~q(2,.Units~newton/.Units~ampere)
act=.LinearElectromechanicalTransducer~new('voice-coil',rb,zero,frame,axis,k)
drive0=.ElectricalDriveObservation~new(.Units~q(0,.Units~second),.Units~q(3,.Units~ampere),.Units~q(12,.Units~volt),'electrical solve','rexx-tronics')
ev0=act~applyDrive(drive0)
call near ev0~forceMagnitude,6,'force from current'
call near ev0~backEmf,0,'stationary back EMF'
call near ev0~mechanicalPower,0,'stationary mechanical power'
call near ev0~terminalElectricalPower,36,'terminal power'
solver~step(.Units~q(.5,.Units~second))
call near rb~velocity~x,1.5,'mechanical velocity after drive'
call near rb~position~x,.75,'mechanical displacement after drive'
drive1=.ElectricalDriveObservation~new(.Units~q(.5,.Units~second),.Units~q(3,.Units~ampere),.Units~q(12,.Units~volt),'electrical re-solve','rexx-tronics')
ev1=act~applyDrive(drive1)
call near ev1~backEmf,3,'reciprocal back EMF'
call near ev1~mechanicalPower,9,'mechanical conversion power'
call near ev1~conversionElectricalPower,9,'electrical conversion power'
call near ev1~powerClosureError,0,'reciprocal power closure'
call near ev1~unassignedTerminalPower,27,'terminal power not assigned to ideal conversion'
if ev1~driveObservation~cause<>'electrical re-solve' then do; say 'FAIL: causal observation lost'; exit 1; end
say 'PHYSICS ELECTROMECHANICAL LINEAR: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Electromechanics.cls'
