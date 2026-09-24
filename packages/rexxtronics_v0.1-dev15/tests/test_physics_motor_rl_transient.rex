numeric digits 40
failures=0
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(0,0,1,ctx)
rotorBody=.PhysicalBody~new('rotor-rl',.SphereShape~new(.1),.PhysicalPose~identity(ctx))
world~addBody(rotorBody)
rotor=.RigidBodyState~new(rotorBody,.MechanicsMassProperties~new(1,1,1,1))
mechanics=.MechanicsSolver~new(world,zero)
mechanics~addBody(rotor)
transducer=.RotaryElectromechanicalTransducer~new('MOTOR-RL',rotor,.PhysicalPose~identity(ctx),axis,.Units~q(.5,.Units~newton*.Units~metre/.Units~ampere))

c=.Circuit~new
v=.StepVoltageSource~new('V1','0 V','3 V','0 ms')
r=.Resistor~new('RW','1 ohm')
l=.Inductor~new('LW','0.1 H','0 A')
emf=.PhysicsBackEmfSource~new('EMF',transducer)
c~add(v); c~add(r); c~add(l); c~add(emf)
c~connectGround(v~negative)
c~connectGround(emf~negative)
c~connect('VCC',.array~of(v~positive,r~pin('A')))
c~connect('R_L',.array~of(r~pin('B'),l~pin('A')))
c~connect('MOTOR',.array~of(l~pin('B'),emf~positive))

clock=.SimulationClock~new
bridge=.PhysicsElectromechanicalDriveBridge~new(emf)
coupler=.TransientElectromechanicalCoupler~new(c,mechanics,clock,'10 ms')
coupler~addBridge(bridge)
initial=coupler~begin
call near l~storedCurrent~in(.Units~ampere),0,'initial winding current','0.0000000001'

first=coupler~step
firstCurrent=first~electricalSolution~current(emf)
if firstCurrent<=0 | firstCurrent>=1 then call fail 'first R-L current should ramp from zero, not jump to DC steady state'
call near l~storedCurrent~in(.Units~ampere),firstCurrent,'inductor history retained after first coupled step','0.000000001'

do 19
  last=coupler~step
end
finalCurrent=last~electricalSolution~current(emf)
finalOmega=rotor~angularVelocity~z
finalEmf=emf~backEmfVolts

if finalCurrent<=firstCurrent then call fail 'winding current should have risen after 200 ms'
if finalOmega<=0 then call fail 'rotor should accelerate under winding current'
if finalEmf<=0 then call fail 'rotor motion should create reciprocal back EMF'
if clock~now~milliseconds<>200 then call fail 'shared simulation clock did not reach 200 ms'
if coupler~stepCount<>20 then call fail 'coupler step count mismatch'
if coupler~result~pointCount<>21 then call fail 'persistent electrical trace should contain t0 plus 20 steps'
call near l~storedCurrent~in(.Units~ampere),finalCurrent,'winding inductor history survives all coupled partitions','0.00000001'

/* Without back EMF this backward-Euler R-L network would be about 2.554 A
 * after the same 20 x 10 ms partitions. Reciprocal motion must reduce it. */
if finalCurrent>=2.554 then call fail 'back EMF did not reduce R-L winding current below uncoupled reference'

if failures=0 then do
  say 'REXX-TRONICS / PHYSICS PERSISTENT R-L MOTOR: OK'
  say 'first-step current A:' firstCurrent
  say 'current at 200 ms A:' finalCurrent
  say 'omega at 200 ms rad/s:' finalOmega
  say 'back EMF at 200 ms V:' finalEmf
  say 'winding stored current A:' l~storedCurrent~in(.Units~ampere)
  say 'electrical trace points:' coupler~result~pointCount
  exit 0
end
say 'FAIL persistent R-L motor failures='failures
exit 1

near: procedure expose failures
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected 'tolerance='tolerance
    failures+=1
  end
return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
return

::requires 'RexxTronicsElectromechanics.cls'
