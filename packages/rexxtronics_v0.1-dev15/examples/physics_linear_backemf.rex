numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(1,0,0,ctx)
body=.PhysicalBody~new('armature',.SphereShape~new(.05),.PhysicalPose~identity(ctx))
world~addBody(body)
armature=.RigidBodyState~new(body,.MechanicsMassProperties~solidSphere(2,.05))
mechanics=.MechanicsSolver~new(world,zero)
mechanics~addBody(armature)
transducer=.LinearElectromechanicalTransducer~new('VOICE_COIL',armature,zero,.PhysicalPose~identity(ctx),axis,.Units~q(2,.Units~newton/.Units~ampere))

c=.Circuit~new
v=.DCVoltageSource~new('V1','12 V')
r=.Resistor~new('RW','2 ohm')
emf=.PhysicsBackEmfSource~new('EMF',transducer)
c~add(v); c~add(r); c~add(emf)
c~connectGround(v~negative)
c~connectGround(emf~negative)
c~connect('VCC',.array~of(v~positive,r~pin('A')))
c~connect('COIL',.array~of(r~pin('B'),emf~positive))

clock=.SimulationClock~new
bridge=.PhysicsElectromechanicalDriveBridge~new(emf)
coupler=.QuasiStaticElectromechanicalCoupler~new(c,mechanics,clock)
coupler~addBridge(bridge)

s0=c~solveDC
call near s0~current(emf),6,'stationary coil current'
step1=coupler~step('100 ms')
call near armature~velocity~x,.6,'armature velocity after first step'
call near armature~position~x,.06,'armature displacement after first step'
call near emf~backEmfVolts,1.2,'linear back EMF after first step'
call near step1~postSolution~current(emf),5.4,'coil current reduced by back EMF'

step2=coupler~step('100 ms')
ev=step2~actuationEvents[1]
call near ev~backEmf,1.2,'second drive back EMF'
call near ev~forceMagnitude,10.8,'second drive force'
call near ev~mechanicalPower,6.48,'linear mechanical conversion power'
call near ev~conversionElectricalPower,6.48,'linear electrical conversion power'
call near ev~powerClosureError,0,'linear reciprocal power closure'

say 'REXX-TRONICS / PHYSICS LINEAR BACK-EMF LOOP: OK'
say 'armature velocity m/s:' armature~velocity~x
say 'back EMF V:' emf~backEmfVolts
say 'post current A:' step2~postSolution~current(emf)
exit 0

near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return

::requires 'RexxTronicsElectromechanics.cls'
