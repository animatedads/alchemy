numeric digits 30
ctx=.Maths~defaultContext
zero=.MathVector3~new(0,0,0,ctx)
world=.PhysicalWorld~new
movingBody=.PhysicalBody~new('diaphragm',.SphereShape~new(.01),.PhysicalPose~identity(ctx))
fixedPose=.PhysicalPose~new(.MathVector3~new(-.01,0,0,ctx),.nil,ctx)
fixedBody=.PhysicalBody~new('speaker-frame',.SphereShape~new(.01),fixedPose)
world~addBody(movingBody); world~addBody(fixedBody)
mass=.01
moving=.RigidBodyState~new(movingBody,.MechanicsMassProperties~pointMass(mass,.01),zero,zero)
fixed=.RigidBodyState~new(fixedBody,.MechanicsMassProperties~pointMass(1,.01),zero,zero,.true)
mech=.MechanicsSolver~new(world,zero)
mech~addBody(moving); mech~addBody(fixed)
pi=4*RxCalcArcTan(1,30,'R')
freq=20
k=mass*(2*pi*freq)**2
zeta=.12
c=2*zeta*RxCalcSqrt(k*mass)
spring=.SpringConstraint~new(moving,fixed,.01,k,c,zero,zero)
mech~addSpring(spring)
axis=.MathVector3~new(1,0,0,ctx)
voice=.LinearElectromechanicalTransducer~new('voice-coil',moving,zero,.PhysicalPose~identity(ctx),axis,.Units~q(4,.Units~newton/.Units~ampere),fixed,zero)
patch=.RigidRadiatingPatch~new('diaphragm-radiator',moving,zero,axis,.Units~q(.005,.Units~squareMetre))
patch~observe(.Units~q(0,.Units~second))
dt=1/2000
duration=.1
steps=(duration/dt)~trunc
do i=0 to steps-1
  t=i*dt
  current=.08*RxCalcSin(2*pi*freq*t,30,'R')
  drive=.ElectricalDriveObservation~new(.Units~q(t,.Units~second),.Units~q(current,.Units~ampere),.nil,'speaker drive','qualification')
  voice~applyDrive(drive)
  mech~step(.Units~q(dt,.Units~second))
  patch~observe(mech~timeQuantity)
end
acoustic=.AcousticSolver~new(world)
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(1,0,0,ctx),.nil,ctx))
buffer=.ContinuousMechanicalAcousticRenderer~render(patch,acoustic,mic,.Units~q(duration,.Units~second),.Units~q(2000,.Units~hertz),.Units~q(0,.Units~second),.Units~q(freq,.Units~hertz))
if buffer~sampleCount<>steps then do; say 'FAIL: speaker sample count'; exit 1; end
if buffer~rmsPressure<=.000001 then do; say 'FAIL: speaker pressure should be non-zero'; exit 1; end
travel=1/.AcousticMedium~air~soundSpeed
preIndex=(travel*2000*.8)~trunc+1
if abs(buffer~pressureAt(preIndex))>.0000001 then do; say 'FAIL: pressure arrived before propagation delay'; exit 1; end
if abs(moving~position~x)<=.0000000001 & moving~velocity~norm<=.0000000001 then do; say 'FAIL: diaphragm never moved'; exit 1; end
say 'PHYSICS ELECTROMECHANICAL SPEAKER: OK'
exit 0
::requires 'DrivenAcoustics.cls'
