numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(0,0,1,ctx)
rotorBody=.PhysicalBody~new('rotor',.SphereShape~new(.1),.PhysicalPose~identity(ctx))
world~addBody(rotorBody)
rotor=.RigidBodyState~new(rotorBody,.MechanicsMassProperties~new(1,1,1,1))
mechanics=.MechanicsSolver~new(world,zero)
mechanics~addBody(rotor)
transducer=.RotaryElectromechanicalTransducer~new('MOTOR',rotor,.PhysicalPose~identity(ctx),axis,.Units~q(.5,.Units~newton*.Units~metre/.Units~ampere))

c=.Circuit~new
v=.DCVoltageSource~new('V1','3 V')
r=.Resistor~new('RW','1 ohm')
emf=.PhysicsBackEmfSource~new('EMF',transducer)
c~add(v); c~add(r); c~add(emf)
c~connectGround(v~negative)
c~connectGround(emf~negative)
c~connect('VCC',.array~of(v~positive,r~pin('A')))
c~connect('MOTOR',.array~of(r~pin('B'),emf~positive))

clock=.SimulationClock~new
bridge=.PhysicsElectromechanicalDriveBridge~new(emf)
coupler=.QuasiStaticElectromechanicalCoupler~new(c,mechanics,clock)
coupler~addBridge(bridge)

s0=c~solveDC
call near s0~current(emf),3,'stationary current'
call near emf~backEmfVolts,0,'stationary back EMF'

step1=coupler~step('100 ms')
call near rotor~angularVelocity~z,.15,'omega after first step'
call near emf~backEmfVolts,.075,'back EMF after first step'
call near step1~postSolution~current(emf),2.925,'current reduced by first back EMF'
if clock~now~milliseconds<>100 then do; say 'FAIL: shared clock did not advance to 100 ms'; exit 1; end

step2=coupler~step('100 ms')
ev=step2~actuationEvents[1]
call near ev~backEmf,.075,'second drive uses current mechanical back EMF'
call near ev~mechanicalPower,.219375,'second-step mechanical conversion power'
call near ev~conversionElectricalPower,.219375,'second-step electrical conversion power'
call near ev~powerClosureError,0,'reciprocal conversion power closure'
call near rotor~angularVelocity~z,.29625,'omega after second step'
call near emf~backEmfVolts,.148125,'back EMF after second step'
call near step2~postSolution~current(emf),2.851875,'current reduced by second back EMF'
if clock~now~milliseconds<>200 then do; say 'FAIL: shared clock did not advance to 200 ms'; exit 1; end

say 'REXX-TRONICS / PHYSICS ROTARY BACK-EMF LOOP: OK'
say 'initial current A:' s0~current(emf)
say 'omega at 200 ms rad/s:' rotor~angularVelocity~z
say 'back EMF V:' emf~backEmfVolts
say 'current at 200 ms A:' step2~postSolution~current(emf)
exit 0

near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return

::requires 'RexxTronicsElectromechanics.cls'
