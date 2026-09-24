/* ooRexx Physics World - manufacturing machine dynamics extension.
   Commands are requests to finite-force actuators.  The physical body remains
   authoritative for actual position/velocity; commanded coordinates never
   teleport machine components.  Internal units are SI.
*/

::class AxisServo public
::method init
  expose _body _axis _kp _kd _maxForce _targetPosition _targetVelocity _lastForce
  use strict arg rigidBody,axis,kp,kd,maxForce,targetPosition=0,targetVelocity=0
  if kp<0 | kd<0 | maxForce<=0 then raise syntax 88.900 array('non-negative gains and positive max force',kp kd maxForce)
  _body=rigidBody; _axis=axis~normalized; _kp=kp; _kd=kd; _maxForce=maxForce
  _targetPosition=targetPosition; _targetVelocity=targetVelocity; _lastForce=0
::method body; expose _body; return _body
::method axis; expose _axis; return _axis
::method targetPosition; expose _targetPosition; return _targetPosition
::method 'targetPosition='; expose _targetPosition; use strict arg v; _targetPosition=v
::method targetVelocity; expose _targetVelocity; return _targetVelocity
::method 'targetVelocity='; expose _targetVelocity; use strict arg v; _targetVelocity=v
::method lastForce; expose _lastForce; return _lastForce
::method position; return self~body~position~dot(self~axis)
::method velocity; return self~body~velocity~dot(self~axis)
::method trackingError; return self~targetPosition-self~position
::method apply
  expose _kp _kd _maxForce _lastForce
  f=_kp*self~trackingError+_kd*(self~targetVelocity-self~velocity)
  if f>_maxForce then f=_maxForce
  if f<-_maxForce then f=-_maxForce
  _lastForce=f
  self~body~applyForce(self~axis*f)
  return f

::class MachineMotionSample public
::method init
  expose _time _commanded _actual _velocity _error _driveForce
  use strict arg timeSeconds,commandedPosition,actualPosition,actualVelocity,error,driveForce
  _time=timeSeconds; _commanded=commandedPosition; _actual=actualPosition
  _velocity=actualVelocity; _error=error; _driveForce=driveForce
::method time; expose _time; return _time
::method commandedPosition; expose _commanded; return _commanded
::method actualPosition; expose _actual; return _actual
::method velocity; expose _velocity; return _velocity
::method error; expose _error; return _error
::method driveForce; expose _driveForce; return _driveForce

::class MachineAxisExperiment public
::method init
  expose _solver _servo _samples _maxAbsError
  use strict arg mechanicsSolver,axisServo
  _solver=mechanicsSolver; _servo=axisServo; _samples=.array~new; _maxAbsError=0
::method solver; expose _solver; return _solver
::method servo; expose _servo; return _servo
::method samples; expose _samples; return _samples~copy
::method maxAbsError; expose _maxAbsError; return _maxAbsError
::method command
  use strict arg position,velocity=0
  self~servo~targetPosition=position
  self~servo~targetVelocity=velocity
::method step
  expose _samples _maxAbsError
  use strict arg dt
  f=self~servo~apply
  self~solver~step(dt)
  e=self~servo~trackingError
  if abs(e)>_maxAbsError then _maxAbsError=abs(e)
  _samples~append(.MachineMotionSample~new(self~solver~time,self~servo~targetPosition,self~servo~position,self~servo~velocity,e,f))
::method runFor
  use strict arg duration,dt
  if duration<=0 | dt<=0 then raise syntax 88.900 array('positive duration and timestep',duration dt)
  elapsed=0
  do while elapsed<duration
    h=dt
    if elapsed+h>duration then h=duration-elapsed
    self~step(h)
    elapsed=elapsed+h
  end

::class CartesianMachineRig public
/* Minimal qualification rig: a finite-mass moving carriage driven along X.
   Payload mass is part of the moving assembly, so changing manufactured mass
   changes the response to exactly the same command and actuator. */
::method create class
  use strict arg carriageMass,payloadMass,kp=800,kd=45,maxForce=80
  if carriageMass<=0 | payloadMass<0 then raise syntax 88.900 array('positive carriage mass and non-negative payload mass',carriageMass payloadMass)
  ctx=.Maths~defaultContext
  world=.PhysicalWorld~new
  body=.OpticalBody~new('machine-carriage',.BoxShape~new('0.1','0.1','0.1',ctx),.nil,.PhysicalPose~identity(ctx))
  totalMass=carriageMass+payloadMass
  rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidBox(totalMass,'0.1','0.1','0.1'),.MathVector3~new(0,0,0,ctx),.nil,.false,0,.nil)
  solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
  solver~addBody(rb)
  servo=.AxisServo~new(rb,.MathVector3~new(1,0,0,ctx),kp,kd,maxForce)
  return .MachineAxisExperiment~new(solver,servo)

::requires 'Mechanics.cls'

/* A manufacturing-side physical projection of a catalogue PartDefinition.
   The catalogue remains identity/metadata authority; this object owns only
   machine-dynamics interpretation needed by a particular experiment. */
::class MachinePartProjection public
::method init
  expose _definition _instanceId _mass _sizeX _sizeY _sizeZ _role
  use strict arg definition,instanceId,mass,sizeX,sizeY,sizeZ,role='PAYLOAD'
  definition~validate
  if mass<=0 | sizeX<=0 | sizeY<=0 | sizeZ<=0 then raise syntax 88.900 array('positive mass and dimensions',mass sizeX sizeY sizeZ)
  _definition=definition; _instanceId=instanceId~string; _mass=mass
  _sizeX=sizeX; _sizeY=sizeY; _sizeZ=sizeZ; _role=role~string~upper
::method definition; expose _definition; return _definition
::method instanceId; expose _instanceId; return _instanceId
::method mass; expose _mass; return _mass
::method sizeX; expose _sizeX; return _sizeX
::method sizeY; expose _sizeY; return _sizeY
::method sizeZ; expose _sizeZ; return _sizeZ
::method role; expose _role; return _role
::method partId; return self~definition~id
::method family; return self~definition~family

::class MachinePartFactory public
::method project class
  use strict arg definition,instanceId,mass,sizeX,sizeY,sizeZ,role='PAYLOAD'
  return .MachinePartProjection~new(definition,instanceId,mass,sizeX,sizeY,sizeZ,role)

::method movingAxisExperiment class
  /* Build the same finite-force X-axis rig from explicit machine parts.
     Mass is summed from the projected physical parts, so adding/changing a
     workpiece changes dynamics without changing the command or controller. */
  use strict arg carriagePart,payloadParts,kp=800,kd=45,maxForce=80
  carriageMass=carriagePart~mass
  payloadMass=0
  if payloadParts<>.nil then do p over payloadParts
    payloadMass=payloadMass+p~mass
  end
  return .CartesianMachineRig~create(carriageMass,payloadMass,kp,kd,maxForce)
