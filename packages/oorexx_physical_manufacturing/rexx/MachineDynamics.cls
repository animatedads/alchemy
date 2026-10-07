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

/* A lateral compliant attachment used for a manufactured payload mounted on a
   moving plate.  It intentionally applies only along the selected machine
   axis; manufacturing owns the attachment interpretation while Mechanics owns
   integration of the physical bodies. */
::class LateralAttachment public
::method init
  expose _base _payload _axis _stiffness _damping _restOffset
  use strict arg baseBody,payloadBody,axis,stiffness,damping=0
  if stiffness<=0 | damping<0 then raise syntax 88.900 array('positive stiffness and non-negative damping',stiffness damping)
  _base=baseBody; _payload=payloadBody; _axis=axis~normalized
  _stiffness=stiffness; _damping=damping
  _restOffset=(payloadBody~position-baseBody~position)~dot(_axis)
::method apply
  expose _base _payload _axis _stiffness _damping _restOffset
  displacement=(_payload~position-_base~position)~dot(_axis)-_restOffset
  relVelocity=(_payload~velocity-_base~velocity)~dot(_axis)
  f=-_stiffness*displacement-_damping*relVelocity
  force=_axis*f
  _payload~applyForce(force)
  _base~applyForce(force*(-1))
  return f

::class RelativeMotionSample public
::method init
  expose _time _commandedHead _commandedPlate _head _plate _workpiece _nozzleToPlate _nozzleToWorkpiece
  use strict arg timeSeconds,commandedHead,commandedPlate,headPosition,platePosition,workpiecePosition
  _time=timeSeconds; _commandedHead=commandedHead; _commandedPlate=commandedPlate
  _head=headPosition; _plate=platePosition; _workpiece=workpiecePosition
  _nozzleToPlate=headPosition-platePosition
  _nozzleToWorkpiece=headPosition-workpiecePosition
::method time; expose _time; return _time
::method commandedHead; expose _commandedHead; return _commandedHead
::method commandedPlate; expose _commandedPlate; return _commandedPlate
::method headPosition; expose _head; return _head
::method platePosition; expose _plate; return _plate
::method workpiecePosition; expose _workpiece; return _workpiece
::method nozzleToPlate; expose _nozzleToPlate; return _nozzleToPlate
::method nozzleToWorkpiece; expose _nozzleToWorkpiece; return _nozzleToWorkpiece

::class CartesianPrinterDynamics public
/* Two independently physical machine axes plus an attached manufactured body.
   Commands drive finite-force servos.  The useful deposition coordinate is
   actual nozzle-to-workpiece displacement, never commanded coordinates. */
::method create class
  use strict arg headMass,plateMass,workpieceMass,workpieceHeight='0.02',workpieceStiffness=1200,workpieceDamping=8,headMaxForce=80,plateMaxForce=120
  if headMass<=0 | plateMass<=0 | workpieceMass<=0 | workpieceHeight<=0 then raise syntax 88.900 array('positive machine/workpiece physical parameters')
  ctx=.Maths~defaultContext; world=.PhysicalWorld~new
  headShape=.BoxShape~new('0.05','0.05','0.05',ctx); plateShape=.BoxShape~new('0.20','0.02','0.20',ctx)
  workShape=.BoxShape~new('0.03',workpieceHeight,'0.03',ctx)
  head=.OpticalBody~new('printer-head',headShape,.nil,.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
  plate=.OpticalBody~new('printer-plate',plateShape,.nil,.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
  work=.OpticalBody~new('manufactured-workpiece',workShape,.nil,.PhysicalPose~new(.MathVector3~new(0,workpieceHeight/2,0,ctx),.nil,ctx))
  hr=.RigidBodyState~new(head,.MechanicsMassProperties~solidBox(headMass,'0.05','0.05','0.05'))
  pr=.RigidBodyState~new(plate,.MechanicsMassProperties~solidBox(plateMass,'0.20','0.02','0.20'))
  wr=.RigidBodyState~new(work,.MechanicsMassProperties~solidBox(workpieceMass,'0.03',workpieceHeight,'0.03'))
  solver=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx)); solver~addBody(hr); solver~addBody(pr); solver~addBody(wr)
  axis=.MathVector3~new(1,0,0,ctx)
  hs=.AxisServo~new(hr,axis,900,50,headMaxForce); ps=.AxisServo~new(pr,axis,900,50,plateMaxForce)
  return self~new(solver,hs,ps,wr,.LateralAttachment~new(pr,wr,axis,workpieceStiffness,workpieceDamping))
::method init
  expose _solver _headServo _plateServo _workpiece _attachment _samples _relativeHistory
  use strict arg solver,headServo,plateServo,workpiece,attachment
  _solver=solver; _headServo=headServo; _plateServo=plateServo; _workpiece=workpiece; _attachment=attachment
  _samples=.array~new; _relativeHistory=.SampledScalarHistory~new
::method commandHead; expose _headServo; use strict arg p,v=0; _headServo~targetPosition=p; _headServo~targetVelocity=v
::method commandPlate; expose _plateServo; use strict arg p,v=0; _plateServo~targetPosition=p; _plateServo~targetVelocity=v
::method step
  expose _solver _headServo _plateServo _workpiece _attachment _samples _relativeHistory
  use strict arg dt
  _headServo~apply; _plateServo~apply; _attachment~apply; _solver~step(dt)
  s=.RelativeMotionSample~new(_solver~time,_headServo~targetPosition,_plateServo~targetPosition,_headServo~position,_plateServo~position,_workpiece~position~x)
  _samples~append(s); _relativeHistory~append(_solver~time,s~nozzleToWorkpiece); return s
::method runFor
  use strict arg duration,dt
  elapsed=0; do while elapsed<duration; h=dt; if elapsed+h>duration then h=duration-elapsed; self~step(h); elapsed=elapsed+h; end
::method samples; expose _samples; return _samples~copy
::method relativeHistory; expose _relativeHistory; return _relativeHistory
::method workpiece; expose _workpiece; return _workpiece

::requires 'SpectralObservations.cls'
