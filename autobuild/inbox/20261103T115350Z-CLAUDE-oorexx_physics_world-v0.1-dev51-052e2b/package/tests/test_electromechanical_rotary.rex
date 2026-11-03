numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(0,0,1,ctx)
body=.PhysicalBody~new('rotor',.SphereShape~new(.1),.PhysicalPose~identity(ctx))
rb=.RigidBodyState~new(body,.MechanicsMassProperties~new(1,1,1,1))
world~addBody(body)
solver=.MechanicsSolver~new(world,zero)
solver~addBody(rb)
act=.RotaryElectromechanicalTransducer~new('ideal-motor',rb,.PhysicalPose~identity(ctx),axis,.Units~q(.5,.Units~newton*.Units~metre/.Units~ampere))
drive0=.ElectricalDriveObservation~new(.Units~q(0,.Units~second),.Units~q(4,.Units~ampere),.Units~q(3,.Units~volt))
ev0=act~applyDrive(drive0)
call near ev0~torqueMagnitude,2,'motor torque'
solver~step(.Units~q(.5,.Units~second))
call near rb~angularVelocity~z,1,'motor angular velocity'
drive1=.ElectricalDriveObservation~new(.Units~q(.5,.Units~second),.Units~q(4,.Units~ampere),.Units~q(3,.Units~volt))
ev1=act~applyDrive(drive1)
call near ev1~backEmf,.5,'rotary back EMF'
call near ev1~mechanicalPower,2,'rotary mechanical power'
call near ev1~conversionElectricalPower,2,'rotary electrical conversion power'
call near ev1~powerClosureError,0,'rotary reciprocal power closure'
call near ev1~unassignedTerminalPower,10,'rotary terminal residual power'
say 'PHYSICS ELECTROMECHANICAL ROTARY: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Electromechanics.cls'
