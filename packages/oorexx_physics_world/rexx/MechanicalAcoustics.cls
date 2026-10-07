/* ooRexx Physics World v0.1-dev7
   Mechanics -> structural vibration -> acoustics coupling.

   This is deliberately a physically named approximation, not a "collision sound"
   shortcut.  A contact impulse excites an explicit under-damped structural mode.
   The mode drives a finite vibrating patch.  The patch is propagated as a compact
   free-space monopole-equivalent source using retarded time:

       p(r,t) = rho / (4*pi*r) * dQ/dt (t-r/c)

   where Q = area * normalVelocity.  This first cut is one-way coupling: acoustic
   radiation loading is not yet fed back into the mechanical mode.  It therefore
   reports mechanical and acoustic evidence separately and makes no claim of full
   vibro-acoustic energy closure.
*/


::class MechanicalAcousticUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0

::class StructuralVibrationMode public
::method init
  expose _name _state _localPoint _localNormal _mass _frequency _damping _area
  use strict arg name,rigidBodyState,localPoint,localNormal,effectiveMassKg,frequencyHz,dampingRatio,radiatingAreaM2
  effectiveMassKg=.MechanicalAcousticUnitBoundary~scalar(effectiveMassKg,.Units~kilogram~dimension,'structural mode effective mass')
  frequencyHz=.MechanicalAcousticUnitBoundary~scalar(frequencyHz,.Units~hertz~dimension,'structural mode frequency')
  dampingRatio=.MechanicalAcousticUnitBoundary~scalar(dampingRatio,.UnitDimension~dimensionless,'structural mode damping ratio')
  radiatingAreaM2=.MechanicalAcousticUnitBoundary~scalar(radiatingAreaM2,.Units~squareMetre~dimension,'structural mode radiating area')
  if effectiveMassKg<=0 then raise syntax 88.900 array('positive structural mode effective mass',effectiveMassKg)
  if frequencyHz<=0 then raise syntax 88.900 array('positive structural mode frequency',frequencyHz)
  if dampingRatio<0 | dampingRatio>=1 then raise syntax 88.900 array('structural mode damping ratio in [0,1)',dampingRatio)
  if radiatingAreaM2<=0 then raise syntax 88.900 array('positive structural mode radiating area',radiatingAreaM2)
  _name=name; _state=rigidBodyState; _localPoint=localPoint; _localNormal=localNormal~normalized
  _mass=effectiveMassKg; _frequency=frequencyHz; _damping=dampingRatio; _area=radiatingAreaM2
::method name; expose _name; return _name
::method rigidBodyState; expose _state; return _state
::method localPoint; expose _localPoint; return _localPoint
::method localNormal; expose _localNormal; return _localNormal
::method effectiveMass; expose _mass; return _mass
::method effectiveMassQuantity; return .Units~q(self~effectiveMass,.Units~kilogram)
::method frequencyHz; expose _frequency; return _frequency
::method frequencyQuantity; return .Units~q(self~frequencyHz,.Units~hertz)
::method dampingRatio; expose _damping; return _damping
::method dampingRatioQuantity; return .Units~q(self~dampingRatio,.Units~one)
::method radiatingArea; expose _area; return _area
::method radiatingAreaQuantity; return .Units~q(self~radiatingArea,.Units~squareMetre)
::method position
  return self~rigidBodyState~body~pose~pointToWorld(self~localPoint)
::method normal
  return self~rigidBodyState~body~pose~directionToWorld(self~localNormal)
::method excite
  use strict arg contactEvent
  impulse=contactEvent~impulseFor(self~rigidBodyState)
  if impulse==.nil then return .nil
  worldNormal=self~normal
  modalImpulse=impulse~dot(worldNormal)
  if abs(modalImpulse)<'0.000000000000001' then return .nil
  initialVelocity=modalImpulse/self~effectiveMass
  return .StructuralModeResponse~new(self,contactEvent~time,initialVelocity,contactEvent,self~position,worldNormal)

::class DeformablePatchVibrationMode public
::method init
  expose _name _body _a _b _c _mass _frequency _damping _area
  use strict arg name,deformableBody,nodeA,nodeB,nodeC,effectiveMassKg,frequencyHz,dampingRatio,radiatingAreaM2
  effectiveMassKg=.MechanicalAcousticUnitBoundary~scalar(effectiveMassKg,.Units~kilogram~dimension,'deformable mode effective mass')
  frequencyHz=.MechanicalAcousticUnitBoundary~scalar(frequencyHz,.Units~hertz~dimension,'deformable mode frequency')
  dampingRatio=.MechanicalAcousticUnitBoundary~scalar(dampingRatio,.UnitDimension~dimensionless,'deformable mode damping ratio')
  radiatingAreaM2=.MechanicalAcousticUnitBoundary~scalar(radiatingAreaM2,.Units~squareMetre~dimension,'deformable mode radiating area')
  if effectiveMassKg<=0 then raise syntax 88.900 array('positive deformable mode effective mass',effectiveMassKg)
  if frequencyHz<=0 then raise syntax 88.900 array('positive deformable mode frequency',frequencyHz)
  if dampingRatio<0 | dampingRatio>=1 then raise syntax 88.900 array('deformable mode damping ratio in [0,1)',dampingRatio)
  if radiatingAreaM2<=0 then raise syntax 88.900 array('positive deformable mode radiating area',radiatingAreaM2)
  _name=name; _body=deformableBody; _a=nodeA; _b=nodeB; _c=nodeC
  _mass=effectiveMassKg; _frequency=frequencyHz; _damping=dampingRatio; _area=radiatingAreaM2
  /* Fail at construction rather than discovering a zero-area patch at impact. */
  dummy=self~normal
::method name; expose _name; return _name
::method deformableBody; expose _body; return _body
::method nodeA; expose _a; return _a
::method nodeB; expose _b; return _b
::method nodeC; expose _c; return _c
::method effectiveMass; expose _mass; return _mass
::method effectiveMassQuantity; return .Units~q(self~effectiveMass,.Units~kilogram)
::method frequencyHz; expose _frequency; return _frequency
::method frequencyQuantity; return .Units~q(self~frequencyHz,.Units~hertz)
::method dampingRatio; expose _damping; return _damping
::method dampingRatioQuantity; return .Units~q(self~dampingRatio,.Units~one)
::method radiatingArea; expose _area; return _area
::method radiatingAreaQuantity; return .Units~q(self~radiatingArea,.Units~squareMetre)
::method position
  return (self~nodeA~position+self~nodeB~position+self~nodeC~position)*(1/3)
::method normal
  ab=self~nodeB~position-self~nodeA~position
  ac=self~nodeC~position-self~nodeA~position
  n=ab~cross(ac)
  if n~norm<'0.000000000001' then raise syntax 88.900 array('non-degenerate deformable acoustic patch','collinear nodes')
  return n~normalized
::method containsNode
  use strict arg node
  return node==self~nodeA | node==self~nodeB | node==self~nodeC
::method excite
  use strict arg contactEvent
  if \contactEvent~isA(.DeformableContactEvent) then return .nil
  if contactEvent~body<>self~deformableBody then return .nil
  if \self~containsNode(contactEvent~node) then return .nil
  impulse=contactEvent~impulseOnNode
  worldNormal=self~normal
  modalImpulse=impulse~dot(worldNormal)
  if abs(modalImpulse)<'0.000000000000001' then return .nil
  initialVelocity=modalImpulse/self~effectiveMass
  return .StructuralModeResponse~new(self,contactEvent~time,initialVelocity,contactEvent,self~position,worldNormal)

::class StructuralModeResponse public
::method init
  expose _mode _startTime _initialVelocity _event _sourcePosition _sourceNormal
  use strict arg mode,startTimeSeconds,initialVelocity,contactEvent,sourcePosition,sourceNormal
  _mode=mode; _startTime=startTimeSeconds; _initialVelocity=initialVelocity; _event=contactEvent
  _sourcePosition=sourcePosition; _sourceNormal=sourceNormal~normalized
::method mode; expose _mode; return _mode
::method contactEvent; expose _event; return _event
::method startTime; expose _startTime; return _startTime
::method startTimeQuantity; return .Units~q(self~startTime,.Units~second)
::method initialVelocity; expose _initialVelocity; return _initialVelocity
::method initialVelocityQuantity; return .Units~q(self~initialVelocity,.Units~metrePerSecond)
::method sourcePosition; expose _sourcePosition; return _sourcePosition
::method sourceNormal; expose _sourceNormal; return _sourceNormal
::method omegaNatural
  pi=4*RxCalcArcTan(1,30,'R')
  return 2*pi*self~mode~frequencyHz
::method omegaDamped
  wn=self~omegaNatural; z=self~mode~dampingRatio
  return wn*RxCalcSqrt(1-z*z)
::method displacementAfter
  use strict arg secondsAfterImpact
  if secondsAfterImpact<0 then return 0
  wn=self~omegaNatural; wd=self~omegaDamped; z=self~mode~dampingRatio
  return (self~initialVelocity/wd)*RxCalcExp(-(z*wn*secondsAfterImpact),30)*RxCalcSin(wd*secondsAfterImpact,30,'R')
::method displacementQuantityAfter
  use strict arg secondsAfterImpact
  secondsAfterImpact=.MechanicalAcousticUnitBoundary~scalar(secondsAfterImpact,.UnitDimension~time,'mode elapsed time')
  return .Units~q(self~displacementAfter(secondsAfterImpact),.Units~metre)
::method velocityAfter
  use strict arg secondsAfterImpact
  if secondsAfterImpact<0 then return 0
  wn=self~omegaNatural; wd=self~omegaDamped; z=self~mode~dampingRatio
  envelope=RxCalcExp(-(z*wn*secondsAfterImpact),30)
  return self~initialVelocity*envelope*(RxCalcCos(wd*secondsAfterImpact,30,'R')-(z*wn/wd)*RxCalcSin(wd*secondsAfterImpact,30,'R'))
::method velocityQuantityAfter
  use strict arg secondsAfterImpact
  secondsAfterImpact=.MechanicalAcousticUnitBoundary~scalar(secondsAfterImpact,.UnitDimension~time,'mode elapsed time')
  return .Units~q(self~velocityAfter(secondsAfterImpact),.Units~metrePerSecond)
::method accelerationAfter
  use strict arg secondsAfterImpact
  if secondsAfterImpact<0 then return 0
  wn=self~omegaNatural; z=self~mode~dampingRatio
  x=self~displacementAfter(secondsAfterImpact); v=self~velocityAfter(secondsAfterImpact)
  return -2*z*wn*v-wn*wn*x
::method accelerationQuantityAfter
  use strict arg secondsAfterImpact
  secondsAfterImpact=.MechanicalAcousticUnitBoundary~scalar(secondsAfterImpact,.UnitDimension~time,'mode elapsed time')
  return .Units~q(self~accelerationAfter(secondsAfterImpact),.Units~metrePerSecondSquared)
::method volumeVelocityAfter
  use strict arg secondsAfterImpact
  return self~mode~radiatingArea*self~velocityAfter(secondsAfterImpact)
::method volumeAccelerationAfter
  use strict arg secondsAfterImpact
  return self~mode~radiatingArea*self~accelerationAfter(secondsAfterImpact)
::method initialMechanicalEnergy
  return self~mode~effectiveMass*self~initialVelocity*self~initialVelocity/2
::method initialMechanicalEnergyQuantity; return .Units~q(self~initialMechanicalEnergy,.Units~joule)
::method mechanicalEnergyAfter
  use strict arg secondsAfterImpact
  if secondsAfterImpact<0 then return 0
  m=self~mode~effectiveMass; wn=self~omegaNatural
  v=self~velocityAfter(secondsAfterImpact); x=self~displacementAfter(secondsAfterImpact)
  return m*(v*v+wn*wn*x*x)/2
::method mechanicalEnergyQuantityAfter
  use strict arg secondsAfterImpact
  secondsAfterImpact=.MechanicalAcousticUnitBoundary~scalar(secondsAfterImpact,.UnitDimension~time,'mode elapsed time')
  return .Units~q(self~mechanicalEnergyAfter(secondsAfterImpact),.Units~joule)

::class StructuralAcousticCoupler public
::method init
  expose _modes _responses _contactEnergy _modalEnergy
  _modes=.array~new; _responses=.array~new; _contactEnergy=0; _modalEnergy=0
::method modes; expose _modes; return _modes~copy
::method responses; expose _responses; return _responses~copy
::method addMode; expose _modes; use strict arg mode; _modes~append(mode); return mode
::method clearResponses
  expose _responses _contactEnergy _modalEnergy
  _responses=.array~new; _contactEnergy=0; _modalEnergy=0
::method contactDissipatedEnergy; expose _contactEnergy; return _contactEnergy
::method contactDissipatedEnergyQuantity; return .Units~q(self~contactDissipatedEnergy,.Units~joule)
::method modalMechanicalEnergy; expose _modalEnergy; return _modalEnergy
::method modalMechanicalEnergyQuantity; return .Units~q(self~modalMechanicalEnergy,.Units~joule)
::method unallocatedDissipatedEnergy; return self~contactDissipatedEnergy-self~modalMechanicalEnergy
::method unallocatedDissipatedEnergyQuantity; return .Units~q(self~unallocatedDissipatedEnergy,.Units~joule)
::method consumeContactEvent
  expose _modes _responses _contactEnergy _modalEnergy
  use strict arg contactEvent
  created=.array~new; eventModalEnergy=0
  do mode over _modes
    response=mode~excite(contactEvent)
    if response<>.nil then do
      created~append(response)
      eventModalEnergy=eventModalEnergy+response~initialMechanicalEnergy
    end
  end
  available=contactEvent~dissipatedEnergy
  tolerance='0.000000000001'; if available>0 then tolerance=available*'0.000000001'+'0.000000000001'
  if eventModalEnergy>available+tolerance then -
    raise syntax 93.900 array('structural modal excitation exceeds contact dissipated-energy budget; refine restitution, effective masses or mode geometry')
  _contactEnergy=_contactEnergy+available
  _modalEnergy=_modalEnergy+eventModalEnergy
  do response over created; _responses~append(response); end
  return created
::method consumeMechanicsStep
  use strict arg mechanicsSolver
  return self~consumeContactEvents(mechanicsSolver~contactEvents)
::method consumeDeformableStep
  use strict arg deformableSolver
  return self~consumeContactEvents(deformableSolver~contactEvents)
::method consumeContactEvents
  use strict arg contactEvents
  created=.array~new
  do event over contactEvents
    made=self~consumeContactEvent(event)
    do response over made; created~append(response); end
  end
  return created

::class MechanicalImpactAcousticRenderer public
::method render class
  use strict arg coupler,acousticSolver,microphone,durationSeconds,sampleRateHz,startTimeSeconds=0
  durationSeconds=.MechanicalAcousticUnitBoundary~scalar(durationSeconds,.UnitDimension~time,'impact audio render duration')
  sampleRateHz=.MechanicalAcousticUnitBoundary~scalar(sampleRateHz,.Units~hertz~dimension,'impact audio sample rate')
  startTimeSeconds=.MechanicalAcousticUnitBoundary~scalar(startTimeSeconds,.UnitDimension~time,'impact audio start time')
  if durationSeconds<0 then raise syntax 88.900 array('non-negative impact render duration',durationSeconds)
  if sampleRateHz<=0 then raise syntax 88.900 array('positive impact audio sample rate',sampleRateHz)
  count=(durationSeconds*sampleRateHz)~trunc
  samples=.array~new
  receiver=microphone~position
  pi=4*RxCalcArcTan(1,30,'R')
  do i=0 to count-1
    t=startTimeSeconds+i/sampleRateHz
    pressure=0
    do response over coupler~responses
      source=response~sourcePosition
      delta=receiver-source; distance=delta~norm
      if distance<'0.000000000001' then iterate
      medium=acousticSolver~mediumForPath(source,receiver)
      transmission=acousticSolver~pathSurfaceTransmission(source,receiver)
      if transmission=0 then iterate
      delay=distance/medium~soundSpeed
      tau=t-delay-response~startTime
      if tau<0 then iterate
      /* Compact-patch monopole equivalent.  The explicit patch area and the
         structural acceleration determine volume acceleration; no arbitrary
         collision-to-audio gain is introduced. */
      dQdt=response~volumeAccelerationAfter(tau)
      p=medium~density*dQdt/(4*pi*distance)
      p=p*medium~propagationFactor(response~mode~frequencyHz,distance)*transmission
      pressure=pressure+p
    end
    samples~append(pressure)
  end
  return .AcousticSampleBuffer~new(samples,sampleRateHz,startTimeSeconds)
::method pressureAt class
  use strict arg response,acousticSolver,microphone,timeSeconds
  timeSeconds=.MechanicalAcousticUnitBoundary~scalar(timeSeconds,.UnitDimension~time,'impact pressure observation time')
  source=response~sourcePosition; receiver=microphone~position
  delta=receiver-source; distance=delta~norm
  if distance<'0.000000000001' then raise syntax 88.900 array('non-zero impact source/listener separation',distance)
  medium=acousticSolver~mediumForPath(source,receiver)
  transmission=acousticSolver~pathSurfaceTransmission(source,receiver)
  if transmission=0 then return 0
  delay=distance/medium~soundSpeed
  tau=timeSeconds-delay-response~startTime
  if tau<0 then return 0
  pi=4*RxCalcArcTan(1,30,'R')
  p=medium~density*response~volumeAccelerationAfter(tau)/(4*pi*distance)
  return p*medium~propagationFactor(response~mode~frequencyHz,distance)*transmission

::requires 'Acoustics.cls'
::requires 'Mechanics.cls'
::requires 'Deformable.cls'
::requires 'rxmath' LIBRARY
