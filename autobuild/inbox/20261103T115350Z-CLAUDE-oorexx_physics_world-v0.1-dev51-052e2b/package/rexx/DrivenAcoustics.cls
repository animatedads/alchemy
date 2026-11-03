/* ooRexx Physics World v0.1-dev9
   Continuous mechanical-motion -> acoustic-pressure coupling.

   This module observes the actual motion of a finite radiating patch on a rigid
   body after Mechanics has applied all forces, springs, damping, reaction forces,
   contacts, etc.  It does not infer sound directly from electrical current.

   Compact-volume radiation model:
       Q = A * v_n
       dQ/dt = A * a_n
       p(r,t) = rho / (4*pi*r) * dQ/dt(t-r/c)

   This is a compact monopole-equivalent approximation.  It is not a full piston
   directivity/baffle/diffraction model and is deliberately named accordingly.
*/

::class DrivenAcousticUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0
::method areaUnit class; return .Units~squareMetre
::method volumeVelocityUnit class; return .Units~cubicMetre/.Units~second
::method volumeAccelerationUnit class; return .Units~cubicMetre/(.Units~second~power(2))

::class RadiatingPatchObservation public
::method init
  expose _time _position _normal _normalVelocity _normalAcceleration _area
  use strict arg timeSeconds,position,normal,normalVelocity,normalAcceleration,areaSquareMetres
  _time=timeSeconds+0; _position=position; _normal=normal~normalized
  _normalVelocity=normalVelocity+0; _normalAcceleration=normalAcceleration+0; _area=areaSquareMetres+0
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method position; expose _position; return _position
::method normal; expose _normal; return _normal
::method normalVelocity; expose _normalVelocity; return _normalVelocity
::method normalVelocityQuantity; return .Units~q(self~normalVelocity,.Units~metrePerSecond)
::method normalAcceleration; expose _normalAcceleration; return _normalAcceleration
::method normalAccelerationQuantity; return .Units~q(self~normalAcceleration,.Units~metrePerSecondSquared)
::method area; expose _area; return _area
::method areaQuantity; return .Units~q(self~area,.Units~squareMetre)
::method volumeVelocity; return self~area*self~normalVelocity
::method volumeVelocityQuantity; return .Units~q(self~volumeVelocity,.DrivenAcousticUnitBoundary~volumeVelocityUnit)
::method volumeAcceleration; return self~area*self~normalAcceleration
::method volumeAccelerationQuantity; return .Units~q(self~volumeAcceleration,.DrivenAcousticUnitBoundary~volumeAccelerationUnit)

::class RigidRadiatingPatch public
::method init
  expose _name _state _localPoint _localNormal _area _history _lastTime _lastVelocity
  use strict arg name,rigidBodyState,localPoint,localNormal,areaQuantity
  _name=name; _state=rigidBodyState; _localPoint=localPoint; _localNormal=localNormal~normalized
  _area=.DrivenAcousticUnitBoundary~scalar(areaQuantity,.Units~squareMetre~dimension,'radiating patch area')
  if _area<=0 then raise syntax 88.900 array('positive radiating patch area',_area)
  _history=.array~new; _lastTime=.nil; _lastVelocity=.nil
::method name; expose _name; return _name
::method state; expose _state; return _state
::method localPoint; expose _localPoint; return _localPoint
::method localNormal; expose _localNormal; return _localNormal
::method area; expose _area; return _area
::method areaQuantity; return .Units~q(self~area,.Units~squareMetre)
::method position; return self~state~body~pose~pointToWorld(self~localPoint)
::method normal; return self~state~body~pose~directionToWorld(self~localNormal)
::method pointVelocity
  p=self~position
  return self~state~velocity+self~state~angularVelocity~cross(p-self~state~position)
::method normalVelocity; return self~pointVelocity~dot(self~normal)
::method observations; expose _history; return _history~copy
::method reset
  expose _history _lastTime _lastVelocity
  _history=.array~new; _lastTime=.nil; _lastVelocity=.nil
  return self
::method observe
  expose _history _lastTime _lastVelocity
  use strict arg timeQuantity
  t=.DrivenAcousticUnitBoundary~scalar(timeQuantity,.UnitDimension~time,'radiating patch observation time')
  if t<0 then raise syntax 88.900 array('non-negative radiating patch observation time',t)
  v=self~normalVelocity
  a=0
  if _lastTime<>.nil then do
    dt=t-_lastTime
    if dt<=0 then raise syntax 88.900 array('strictly increasing radiating patch observation time',t)
    a=(v-_lastVelocity)/dt
  end
  obs=.RadiatingPatchObservation~new(t,self~position,self~normal,v,a,self~area)
  _history~append(obs); _lastTime=t; _lastVelocity=v
  return obs
::method firstTime
  expose _history
  if _history~items=0 then return .nil
  return _history[1]~time
::method lastTime
  expose _history
  if _history~items=0 then return .nil
  return _history[_history~items]~time
::method observationAt
  expose _history
  use strict arg timeSeconds
  t=.DrivenAcousticUnitBoundary~scalar(timeSeconds,.UnitDimension~time,'radiating patch interpolation time')
  n=_history~items
  if n=0 then return .nil
  if t<_history[1]~time | t>_history[n]~time then return .nil
  if n=1 then do
    if t=_history[1]~time then return _history[1]
    return .nil
  end
  do i=1 to n-1
    a=_history[i]; b=_history[i+1]
    if t<a~time | t>b~time then iterate
    dt=b~time-a~time
    if dt=0 then return a
    f=(t-a~time)/dt
    pos=a~position+(b~position-a~position)*f
    nrm=a~normal+(b~normal-a~normal)*f
    if nrm~norm<'0.000000000001' then nrm=a~normal
    else nrm=nrm~normalized
    v=a~normalVelocity+(b~normalVelocity-a~normalVelocity)*f
    acc=a~normalAcceleration+(b~normalAcceleration-a~normalAcceleration)*f
    return .RadiatingPatchObservation~new(t,pos,nrm,v,acc,self~area)
  end
  return .nil

::class ContinuousMechanicalAcousticRenderer public
::method pressureAt class
  use strict arg radiator,acousticSolver,microphone,receiveTime,attenuationFrequency=.nil
  t=.DrivenAcousticUnitBoundary~scalar(receiveTime,.UnitDimension~time,'continuous acoustic receive time')
  if t<0 then raise syntax 88.900 array('non-negative continuous acoustic receive time',t)
  first=radiator~firstTime; last=radiator~lastTime
  if first==.nil then return 0
  receiver=microphone~position
  /* Fixed-point retarded-time solve for a moving compact source. */
  tau=t
  if tau>last then tau=last
  obs=radiator~observationAt(tau)
  if obs==.nil then obs=radiator~observationAt(last)
  if obs==.nil then return 0
  do iter=1 to 6
    delta=receiver-obs~position; distance=delta~norm
    if distance<'0.000000000001' then raise syntax 88.900 array('non-zero radiating patch/listener separation',distance)
    medium=acousticSolver~mediumForPath(obs~position,receiver)
    nextTau=t-distance/medium~soundSpeed
    if nextTau<first | nextTau>last then return 0
    nextObs=radiator~observationAt(nextTau)
    if nextObs==.nil then return 0
    if abs(nextTau-tau)<'0.000000000001' then do; tau=nextTau; obs=nextObs; leave; end
    tau=nextTau; obs=nextObs
  end
  delta=receiver-obs~position; distance=delta~norm
  medium=acousticSolver~mediumForPath(obs~position,receiver)
  transmission=acousticSolver~pathSurfaceTransmission(obs~position,receiver)
  if transmission=0 then return 0
  pi=4*RxCalcArcTan(1,30,'R')
  p=medium~density*obs~volumeAcceleration/(4*pi*distance)
  if attenuationFrequency<>.nil then do
    f=.DrivenAcousticUnitBoundary~scalar(attenuationFrequency,.Units~hertz~dimension,'continuous acoustic attenuation reference frequency')
    if f<0 then raise syntax 88.900 array('non-negative acoustic attenuation frequency',f)
    p=p*medium~propagationFactor(f,distance)
  end
  return p*transmission
::method pressureQuantityAt class
  use strict arg radiator,acousticSolver,microphone,receiveTime,attenuationFrequency=.nil
  return .Units~q(self~pressureAt(radiator,acousticSolver,microphone,receiveTime,attenuationFrequency),.Units~pascal)
::method render class
  use strict arg radiator,acousticSolver,microphone,duration,sampleRate,startTime=0,attenuationFrequency=.nil
  duration=.DrivenAcousticUnitBoundary~scalar(duration,.UnitDimension~time,'continuous acoustic render duration')
  sampleRate=.DrivenAcousticUnitBoundary~scalar(sampleRate,.Units~hertz~dimension,'continuous acoustic sample rate')
  startTime=.DrivenAcousticUnitBoundary~scalar(startTime,.UnitDimension~time,'continuous acoustic render start time')
  if duration<0 then raise syntax 88.900 array('non-negative continuous acoustic render duration',duration)
  if sampleRate<=0 then raise syntax 88.900 array('positive continuous acoustic sample rate',sampleRate)
  samples=.array~new
  count=(duration*sampleRate)~trunc
  do i=0 to count-1
    t=startTime+i/sampleRate
    samples~append(self~pressureAt(radiator,acousticSolver,microphone,.Units~q(t,.Units~second),attenuationFrequency))
  end
  return .AcousticSampleBuffer~new(samples,sampleRate,startTime)

::requires 'Electromechanics.cls'
::requires 'Acoustics.cls'
::requires 'Mechanics.cls'
::requires 'rxmath' LIBRARY
