numeric digits 30
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
world=.PhysicalWorld~new
movingBody=.PhysicalBody~new('diaphragm',.SphereShape~new(.01),.PhysicalPose~identity(ctx))
frameBody=.PhysicalBody~new('speaker-frame',.SphereShape~new(.01),.PhysicalPose~new(.MathVector3~new(-.01,0,0,ctx),.nil,ctx))
world~addBody(movingBody); world~addBody(frameBody)
mass=.01
moving=.RigidBodyState~new(movingBody,.MechanicsMassProperties~pointMass(mass,.01),zero,zero)
frame=.RigidBodyState~new(frameBody,.MechanicsMassProperties~pointMass(1,.01),zero,zero,.true)
mechanics=.MechanicsSolver~new(world,zero); mechanics~addBody(moving); mechanics~addBody(frame)
pi=4*RxCalcArcTan(1,30,'R'); frequency=200
stiffness=mass*(2*pi*frequency)**2
damping=2*.15*RxCalcSqrt(stiffness*mass)
mechanics~addSpring(.SpringConstraint~new(moving,frame,.01,stiffness,damping,zero,zero))
axis=.MathVector3~new(1,0,0,ctx)
voice=.LinearElectromechanicalTransducer~new('voice-coil',moving,zero,.PhysicalPose~identity(ctx),axis,.Units~q(4,.Units~newton/.Units~ampere),frame,zero)
radiator=.RigidRadiatingPatch~new('diaphragm',moving,zero,axis,.Units~q(.005,.Units~squareMetre))
radiator~observe(.Units~q(0,.Units~second))
dt=1/8000; duration=.04; currentPeak=.08
steps=(duration/dt)~trunc
lastEvent=.nil
do i=0 to steps-1
  t=i*dt
  current=currentPeak*RxCalcSin(2*pi*frequency*t,30,'R')
  drive=.ElectricalDriveObservation~new(.Units~q(t,.Units~second),.Units~q(current,.Units~ampere),.nil,'Rexx-tronics speaker current','example')
  lastEvent=voice~applyDrive(drive)
  mechanics~step(.Units~q(dt,.Units~second))
  radiator~observe(mechanics~timeQuantity)
end
acoustics=.AcousticSolver~new(world)
mic=.AcousticMicrophone~new('one-metre-mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
buffer=.ContinuousMechanicalAcousticRenderer~render(radiator,acoustics,mic,.Units~q(duration,.Units~second),.Units~q(8000,.Units~hertz),.Units~q(0,.Units~second),.Units~q(frequency,.Units~hertz))
say 'drive frequency:' frequency 'Hz'
say 'diaphragm final displacement:' moving~position~x 'm'
say 'diaphragm final velocity:' moving~velocity~x 'm/s'
say 'back EMF at final drive observation:' lastEvent~backEmf 'V'
say 'microphone RMS pressure:' buffer~rmsPressure 'Pa'
say 'microphone peak pressure:' buffer~peakAbsPressure 'Pa'
say 'microphone RMS SPL:' buffer~rmsSplDb 'dB re 20 uPa'
::requires 'DrivenAcoustics.cls'
