numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(0,0,1,ctx)
body=.PhysicalBody~new('rotor-rl',.SphereShape~new(.1),.PhysicalPose~identity(ctx))
world~addBody(body)
rotor=.RigidBodyState~new(body,.MechanicsMassProperties~new(1,1,1,1))
mechanics=.MechanicsSolver~new(world,zero)
mechanics~addBody(rotor)
transducer=.RotaryElectromechanicalTransducer~new('MOTOR-RL',rotor,.PhysicalPose~identity(ctx),axis,.Units~q(.5,.Units~newton*.Units~metre/.Units~ampere))

c=.Circuit~new
v=.StepVoltageSource~new('V1','0 V','3 V','0 ms')
r=.Resistor~new('RW','1 ohm')
l=.Inductor~new('LW','0.1 H','0 A')
emf=.PhysicsBackEmfSource~new('EMF',transducer)
c~add(v); c~add(r); c~add(l); c~add(emf)
c~connectGround(v~negative); c~connectGround(emf~negative)
c~connect('VCC',.array~of(v~positive,r~pin('A')))
c~connect('R_L',.array~of(r~pin('B'),l~pin('A')))
c~connect('MOTOR',.array~of(l~pin('B'),emf~positive))

clock=.SimulationClock~new
coupler=.TransientElectromechanicalCoupler~new(c,mechanics,clock,'10 ms')
coupler~addBridge(.PhysicsElectromechanicalDriveBridge~new(emf))
coupler~begin
do 20
  step=coupler~step
end
say 'time:' clock~now~milliseconds 'ms'
say 'winding current:' step~electricalSolution~current(emf) 'A'
say 'rotor omega:' rotor~angularVelocity~z 'rad/s'
say 'back EMF:' emf~backEmfVolts 'V'
say 'inductor stored current:' l~storedCurrent
::requires 'RexxTronicsElectromechanics.cls'
