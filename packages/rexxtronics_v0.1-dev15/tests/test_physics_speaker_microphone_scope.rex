numeric digits 30
failures=0
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
axis=.MathVector3~new(1,0,0,ctx)
world=.PhysicalWorld~new
movingBody=.PhysicalBody~new('speaker-diaphragm',.SphereShape~new(.01),.PhysicalPose~identity(ctx))
framePose=.PhysicalPose~new(.MathVector3~new(-.01,0,0,ctx),.nil,ctx)
frameBody=.PhysicalBody~new('speaker-frame',.SphereShape~new(.01),framePose)
world~addBody(movingBody); world~addBody(frameBody)
mass=.01
moving=.RigidBodyState~new(movingBody,.MechanicsMassProperties~pointMass(mass,.01),zero,zero)
frame=.RigidBodyState~new(frameBody,.MechanicsMassProperties~pointMass(1,.01),zero,zero,.true)
mechanics=.MechanicsSolver~new(world,zero)
mechanics~addBody(moving); mechanics~addBody(frame)
pi=4*RxCalcArcTan(1,30,'R')
frequency=200
stiffness=mass*(2*pi*frequency)**2
damping=2*.15*RxCalcSqrt(stiffness*mass)
mechanics~addSpring(.SpringConstraint~new(moving,frame,.01,stiffness,damping,zero,zero))
voice=.LinearElectromechanicalTransducer~new('voice-coil',moving,zero,.PhysicalPose~identity(ctx),axis,.Units~q(4,.Units~newton/.Units~ampere),frame,zero)
radiator=.RigidRadiatingPatch~new('diaphragm-radiator',moving,zero,axis,.Units~q(.005,.Units~squareMetre))
radiator~observe(.Units~q(0,.Units~second))

/* Actual electrical loudspeaker winding: sine source + copper R + winding L + reciprocal back EMF. */
c=.Circuit~new
source=c~add(.SineVoltageSource~new('AUDIO','0 V','1 V','200 Hz'))
rw=c~add(.Resistor~new('RW','8 ohm'))
lw=c~add(.Inductor~new('LW','1 mH','0 A'))
emf=c~add(.PhysicsBackEmfSource~new('EMF',voice))
c~connectGround(source~negative); c~connectGround(emf~negative)
c~connect('DRIVE',.array~of(source~positive,rw~pin('A')))
c~connect('R_L',.array~of(rw~pin('B'),lw~pin('A')))
c~connect('COIL',.array~of(lw~pin('B'),emf~positive))
clock=.SimulationClock~new
coupler=.TransientElectromechanicalCoupler~new(c,mechanics,clock,'0.5 ms')
coupler~addBridge(.PhysicsElectromechanicalDriveBridge~new(emf))
coupler~begin
steps=40
do i=1 to steps
  electricalStep=coupler~step
  radiator~observe(mechanics~timeQuantity)
end
if abs(moving~velocity~x)<=.000000001 then call fail 'speaker diaphragm never moved'
if radiator~observations~items<>steps+1 then call fail 'radiator did not retain each mechanics observation'

/* Physics renders sound from resolved diaphragm acceleration, not from current. */
acoustic=.AcousticSolver~new(world)
physicalMic=.AcousticMicrophone~new('air-mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
buffer=.ContinuousMechanicalAcousticRenderer~render(radiator,acoustic,physicalMic,.Units~q(.02,.Units~second),.Units~q(10000,.Units~hertz),.Units~q(0,.Units~second),.Units~q(frequency,.Units~hertz))
if buffer~rmsPressure<=.000000001 then call fail 'resolved diaphragm motion produced no acoustic pressure'

/* Convert Physics pressure back to a real electrical source and observe it on a Rexx-tronics scope. */
micCircuit=.Circuit~new
mic=.LinearMicrophoneTransducer~new('MIC',.Units~q(.05,.Units~volt/.Units~pascal),'2.5 V','0 V','5 V')
mic~bindAcousticBuffer(buffer)
load=.Resistor~new('MICLOAD','100 kOhm')
micCircuit~add(mic); micCircuit~add(load)
micCircuit~connect('MICOUT',.array~of(mic~output,load~pin('A')))
micCircuit~connectGround(mic~reference); micCircuit~connectGround(load~pin('B'))
micClock=.SimulationClock~new
micRun=micCircuit~simulateTransient(micClock,.Units~q(19.9,.Units~millisecond),.Units~q(100,.Units~microsecond))
scope=.VirtualOscilloscope~new
trace=scope~acquireSignal(micRun~signal('MICOUT'),.Units~q(4,.Units~millisecond),.Units~q(15,.Units~millisecond),.Units~q(10,.Units~kilohertz))
measured=trace~measuredFrequency('2.5 V')
if measured==.nil then call fail 'scope could not recover speaker frequency from microphone waveform'
else if abs(measured-frequency)>5 then call fail 'scope frequency does not track 200 Hz speaker drive'
if trace~maxVoltage-trace~minVoltage<=.000001 then call fail 'microphone electrical waveform is flat'

if failures=0 then do
  say 'REXX-TRONICS ELECTRICAL SPEAKER -> PHYSICS -> MICROPHONE -> SCOPE: OK'
  say 'speaker winding current A:' electricalStep~electricalSolution~current(emf)
  say 'speaker back EMF V:' emf~backEmfVolts
  say 'diaphragm velocity m/s:' moving~velocity~x
  say 'microphone RMS pressure Pa:' buffer~rmsPressure
  say 'scope measured Hz:' measured
  say 'scope min/max V:' trace~minVoltage trace~maxVoltage
  exit 0
end
say 'FAIL speaker/microphone/scope failures='failures
exit 1

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
return

::requires 'RexxTronicsElectromechanics.cls'
::requires 'RexxTronicsAcoustics.cls'
::requires 'DrivenAcoustics.cls'
