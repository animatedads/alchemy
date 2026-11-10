/* ooRexx Physics World v0.1-dev7
   Retained/contained-liquid rigid-vessel helpers.

   This is deliberately NOT a free-surface/slosh/spill solver.  It covers the
   physically distinct case where the liquid is retained and, for gross rigid-body
   motion, moves with the vessel.  The liquid mass and inertia are derived from the
   same FluidMedium density and explicit cavity geometry.  Open-vessel retained free-surface slosh is now provided separately by
   FreeSurfaceFluids.cls for a rectangular one-dimensional shallow-water tank.
   Spill, dry fronts, breaking waves and fully general fluid-structure interaction
   remain outside this retained-load helper and are not represented by a guessed
   fill/alignment factor.
*/

::class VesselUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0

::class FreeFallDrop public
::method init
  expose _height _gravity
  use strict arg dropHeight,gravityMagnitude='9.80665'
  dropHeight=.VesselUnitBoundary~scalar(dropHeight,.UnitDimension~length,'free-fall drop height')
  gravityMagnitude=.VesselUnitBoundary~scalar(gravityMagnitude,.Units~metrePerSecondSquared~dimension,'free-fall gravity magnitude')
  if dropHeight<0 then raise syntax 88.900 array('non-negative free-fall height',dropHeight)
  if gravityMagnitude<=0 then raise syntax 88.900 array('positive gravity magnitude',gravityMagnitude)
  _height=dropHeight; _gravity=gravityMagnitude
::method height; expose _height; return _height
::method heightQuantity; return .Units~q(self~height,.Units~metre)
::method gravityMagnitude; expose _gravity; return _gravity
::method gravityQuantity; return .Units~q(self~gravityMagnitude,.Units~metrePerSecondSquared)
::method impactSpeed
  numeric digits 50
  return RxCalcSqrt(2*self~gravityMagnitude*self~height,40)
::method impactSpeedQuantity; return .Units~q(self~impactSpeed,.Units~metrePerSecond)
::method fallTime
  numeric digits 50
  return RxCalcSqrt(2*self~height/self~gravityMagnitude,40)
::method fallTimeQuantity; return .Units~q(self~fallTime,.Units~second)

::class ContainedFluidLoad public
::method init
  expose _medium _volume _massProperties _radius _height
  use strict arg fluidMedium,volume,massProperties,radius=.nil,height=.nil
  _medium=fluidMedium; _volume=volume; _massProperties=massProperties; _radius=radius; _height=height
::method medium; expose _medium; return _medium
::method volume; expose _volume; return _volume
::method volumeQuantity; return .Units~q(self~volume,.Units~cubicMetre)
::method massProperties; expose _massProperties; return _massProperties
::method mass; return self~massProperties~mass
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method radius; expose _radius; return _radius
::method height; expose _height; return _height
::method filledCylinder class
  use strict arg fluidMedium,radius,height
  radius=.FluidUnitBoundary~scalar(radius,.UnitDimension~length,'contained-fluid cylinder radius')
  height=.FluidUnitBoundary~scalar(height,.UnitDimension~length,'contained-fluid cylinder height')
  if radius<=0 | height<=0 then raise syntax 88.900 array('positive contained-fluid cylinder dimensions',radius height)
  pi=4*RxCalcArcTan(1,30,'R')
  volume=pi*radius*radius*height
  mass=fluidMedium~density*volume
  props=.MechanicsMassProperties~solidCylinder(mass,radius,height)
  return self~new(fluidMedium,volume,props,radius,height)
::method filledCylinderByVolume class
  use strict arg fluidMedium,radius,volume
  numeric digits 50
  radius=.VesselUnitBoundary~scalar(radius,.UnitDimension~length,'contained-fluid cylinder radius')
  volume=.VesselUnitBoundary~scalar(volume,.Units~cubicMetre~dimension,'contained-fluid volume')
  if radius<=0 | volume<=0 then raise syntax 88.900 array('positive contained-fluid radius and volume',radius volume)
  pi=4*RxCalcArcTan(1,40,'R')
  height=volume/(pi*radius*radius)
  return self~filledCylinder(fluidMedium,radius,height)
::method combineCenteredAligned
  /* Both components must share the same centre and principal axes. */
  use strict arg dryMassProperties
  wet=self~massProperties
  return .MechanicsMassProperties~new( -
    dryMassProperties~mass+wet~mass, -
    dryMassProperties~ix+wet~ix, -
    dryMassProperties~iy+wet~iy, -
    dryMassProperties~iz+wet~iz)

::class VesselImpactReport public
::method init
  expose _mass _turns _contacts _peakPressure _rmsPressure _spl _duration _fullTurns _peakOmega _buffer
  use strict arg totalMassKg,turns,contacts,peakPressurePa,rmsPressurePa,splDb,durationSeconds,fullTurns=.nil,peakAngularSpeed=.nil,sampleBuffer=.nil
  _mass=totalMassKg; _turns=turns; _contacts=contacts; _peakPressure=peakPressurePa; _rmsPressure=rmsPressurePa; _spl=splDb; _duration=durationSeconds
  if fullTurns==.nil then fullTurns=turns~trunc
  if peakAngularSpeed==.nil then peakAngularSpeed=0
  _fullTurns=fullTurns; _peakOmega=peakAngularSpeed; _buffer=sampleBuffer
::method totalMass; expose _mass; return _mass
::method totalMassQuantity; return .Units~q(self~totalMass,.Units~kilogram)
::method turns; expose _turns; return _turns
::method fullTurns; expose _fullTurns; return _fullTurns
::method contacts; expose _contacts; return _contacts
::method peakAngularSpeed; expose _peakOmega; return _peakOmega
::method peakAngularSpeedQuantity; return .Units~q(self~peakAngularSpeed,.Units~radian/.Units~second)
::method peakPressure; expose _peakPressure; return _peakPressure
::method peakPressureQuantity; return .Units~q(self~peakPressure,.Units~pascal)
::method rmsPressure; expose _rmsPressure; return _rmsPressure
::method rmsPressureQuantity; return .Units~q(self~rmsPressure,.Units~pascal)
::method splDb; expose _spl; return _spl
::method duration; expose _duration; return _duration
::method durationQuantity; return .Units~q(self~duration,.Units~second)
::method sampleBuffer; expose _buffer; return _buffer

::class VesselImpactExperiment public
::method init
  expose _solver _state _tracker _coupler _acoustic _microphone
  use strict arg mechanicsSolver,vesselRigidBodyState,structuralAcousticCoupler,acousticSolver,microphone
  _solver=mechanicsSolver; _state=vesselRigidBodyState; _tracker=.RigidTumbleTracker~new(vesselRigidBodyState)
  _coupler=structuralAcousticCoupler; _acoustic=acousticSolver; _microphone=microphone
::method tracker; expose _tracker; return _tracker
::method run
  expose _solver _state _tracker _coupler _acoustic _microphone
  use strict arg duration,dt,sampleRate,startTime=.nil
  duration=.VesselUnitBoundary~scalar(duration,.UnitDimension~time,'vessel impact experiment duration')
  dt=.VesselUnitBoundary~scalar(dt,.UnitDimension~time,'vessel impact experiment timestep')
  sampleRate=.VesselUnitBoundary~scalar(sampleRate,.Units~hertz~dimension,'vessel impact experiment sample rate')
  if duration<=0 | dt<=0 | sampleRate<=0 then raise syntax 88.900 array('positive vessel experiment duration, timestep and sample rate',duration dt sampleRate)
  if startTime==.nil then startTime=_solver~time
  else startTime=.VesselUnitBoundary~scalar(startTime,.UnitDimension~time,'vessel impact experiment start time')
  elapsed=0
  do while elapsed<duration
    step=dt
    if elapsed+step>duration then step=duration-elapsed
    if step<='0.000000000001' then leave
    _solver~step(step)
    _tracker~observeStep(_solver,step)
    _coupler~consumeMechanicsStep(_solver)
    elapsed=elapsed+step
  end
  buffer=.MechanicalImpactAcousticRenderer~render(_coupler,_acoustic,_microphone,duration,sampleRate,startTime)
  spl=buffer~rmsSplDb
  return .VesselImpactReport~new(_state~mass,_tracker~turns,_tracker~contactCount,buffer~peakAbsPressure,buffer~rmsPressure,spl,duration,_tracker~fullTurns,_tracker~peakAngularSpeed,buffer)

::requires 'Fluids.cls'
::requires 'ContactDynamics.cls'
::requires 'MechanicalAcoustics.cls'
::requires 'rxmath' LIBRARY
