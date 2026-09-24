/* ooRexx Physics World v0.1-dev7
   Fluid statics/dynamics foundation over the shared PhysicalWorld.

   Dev5 is deliberately not a general CFD claim.  It provides:
   - Newtonian constant-property fluid media;
   - shared spatial fluid regions in PhysicalWorld;
   - typed hydrostatic, uniform and rigid-rotation flow fields;
   - laminar circular-pipe (Hagen-Poiseuille) flow;
   - Reynolds/dynamic-pressure helpers;
   - deterministic RK4 pathline tracing through a velocity field;
   - explicit fully-submerged buoyancy + constant-Cd drag coupling to rigid bodies.

   Canonical internal mechanics use metres, kilograms, seconds, pascals and
   metres/second only after shared Units dimensional validation.
*/

::class FluidUnitBoundary public
::method canonical class
  use strict arg value,expectedDimension,label
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue
  end
  return value
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  return self~canonical(value,expectedDimension,label)+0
::method dynamicViscosityUnit class; return .Units~pascal*.Units~second
::method kinematicViscosityUnit class; return .Units~squareMetre/.Units~second
::method volumetricFlowUnit class; return .Units~cubicMetre/.Units~second
::method massFlowUnit class; return .Units~kilogram/.Units~second
::method accelerationUnit class; return .Units~metrePerSecondSquared

::class FluidMedium public
::method init
  expose _name _density _dynamicViscosity _model
  use strict arg name,density,dynamicViscosity,model='NEWTONIAN_INCOMPRESSIBLE'
  density=.FluidUnitBoundary~scalar(density,.Units~kilogramPerCubicMetre~dimension,'fluid density')
  dynamicViscosity=.FluidUnitBoundary~scalar(dynamicViscosity,.FluidUnitBoundary~dynamicViscosityUnit~dimension,'dynamic viscosity')
  if density<=0 then raise syntax 88.900 array('positive fluid density',density)
  if dynamicViscosity<=0 then raise syntax 88.900 array('positive dynamic viscosity',dynamicViscosity)
  _name=name; _density=density; _dynamicViscosity=dynamicViscosity; _model=model~upper
::method name; expose _name; return _name
::method density; expose _density; return _density
::method dynamicViscosity; expose _dynamicViscosity; return _dynamicViscosity
::method constitutiveModel; expose _model; return _model
::method kinematicViscosity
  numeric digits 40
  return self~dynamicViscosity/self~density
::method densityQuantity; return .Units~q(self~density,.Units~kilogramPerCubicMetre)
::method dynamicViscosityQuantity; return .Units~q(self~dynamicViscosity,.FluidUnitBoundary~dynamicViscosityUnit)
::method kinematicViscosityQuantity; return .Units~q(self~kinematicViscosity,.FluidUnitBoundary~kinematicViscosityUnit)
::method water20C class
  /* Approximate development reference state near 20 C, not metrology data. */
  return self~new('water-20C-approx','998.2','0.001002')
::method air20C class
  /* Useful low-speed reference properties.  Compressibility is not modelled here. */
  return self~new('air-20C-approx','1.2041','0.00001825')

::class FluidMediumRegion subclass PhysicalMediumRegion public
::method init
  use strict arg name,shape,fluidMedium,pose=.nil,priority=10,opticalMedium=.nil,acousticMedium=.nil
  self~init:super(name,shape,opticalMedium,acousticMedium,pose,priority,fluidMedium)

::class FluidState public
::method init
  expose _medium _position _velocity _pressure _time
  use strict arg medium,position,velocity,pressure=0,time=0
  pressure=.FluidUnitBoundary~scalar(pressure,.Units~pascal~dimension,'fluid pressure')
  time=.FluidUnitBoundary~scalar(time,.UnitDimension~time,'fluid state time')
  _medium=medium; _position=position; _velocity=velocity; _pressure=pressure; _time=time
::method medium; expose _medium; return _medium
::method position; expose _position; return _position
::method velocity; expose _velocity; return _velocity
::method pressure; expose _pressure; return _pressure
::method time; expose _time; return _time
::method speed; return self~velocity~norm
::method speedQuantity; return .Units~q(self~speed,.Units~metrePerSecond)
::method pressureQuantity; return .Units~q(self~pressure,.Units~pascal)
::method densityQuantity; return self~medium~densityQuantity
::method dynamicViscosityQuantity; return self~medium~dynamicViscosityQuantity
::method dynamicPressure
  numeric digits 40
  return self~medium~density*self~speed*self~speed/2
::method dynamicPressureQuantity; return .Units~q(self~dynamicPressure,.Units~pascal)

::class FluidField public
::method stateAt
  use strict arg point,time=0
  raise syntax 93.900 array('FluidField~stateAt must be implemented')
::method velocityAt
  use strict arg point,time=0
  return self~stateAt(point,time)~velocity
::method pressureAt
  use strict arg point,time=0
  return self~stateAt(point,time)~pressure

::class UniformFluidField subclass FluidField public
::method init
  expose _medium _velocity _pressure
  use strict arg medium,velocity=.nil,pressure=0
  if velocity==.nil then velocity=.MathVector3~new(0,0,0,.Maths~defaultContext)
  pressure=.FluidUnitBoundary~scalar(pressure,.Units~pascal~dimension,'uniform field pressure')
  _medium=medium; _velocity=velocity; _pressure=pressure
::method medium; expose _medium; return _medium
::method velocity; expose _velocity; return _velocity
::method pressure; expose _pressure; return _pressure
::method stateAt
  expose _medium _velocity _pressure
  use strict arg point,time=0
  return .FluidState~new(_medium,point,_velocity,_pressure,time)

::class HydrostaticFluidField subclass FluidField public
::method init
  expose _medium _referencePoint _referencePressure _gravity
  use strict arg medium,referencePoint,referencePressure=0,gravity=.nil
  referencePressure=.FluidUnitBoundary~scalar(referencePressure,.Units~pascal~dimension,'hydrostatic reference pressure')
  if gravity==.nil then gravity=.MathVector3~new(0,'-9.80665',0,referencePoint~context)
  _medium=medium; _referencePoint=referencePoint; _referencePressure=referencePressure; _gravity=gravity
::method medium; expose _medium; return _medium
::method referencePoint; expose _referencePoint; return _referencePoint
::method referencePressure; expose _referencePressure; return _referencePressure
::method gravity; expose _gravity; return _gravity
::method pressureAt
  expose _medium _referencePoint _referencePressure _gravity
  use strict arg point,time=0
  numeric digits 40
  delta=point-_referencePoint
  return _referencePressure+_medium~density*_gravity~dot(delta)
::method stateAt
  expose _medium
  use strict arg point,time=0
  zero=.MathVector3~new(0,0,0,point~context)
  return .FluidState~new(_medium,point,zero,self~pressureAt(point,time),time)

::class RigidRotationFluidField subclass FluidField public
::method init
  expose _medium _centre _angularVelocity _referencePressure
  use strict arg medium,centre,angularVelocity,referencePressure=0
  referencePressure=.FluidUnitBoundary~scalar(referencePressure,.Units~pascal~dimension,'rotating-fluid reference pressure')
  _medium=medium; _centre=centre; _angularVelocity=angularVelocity; _referencePressure=referencePressure
::method medium; expose _medium; return _medium
::method centre; expose _centre; return _centre
::method angularVelocity; expose _angularVelocity; return _angularVelocity
::method referencePressure; expose _referencePressure; return _referencePressure
::method velocityAt
  expose _centre _angularVelocity
  use strict arg point,time=0
  return _angularVelocity~cross(point-_centre)
::method pressureAt
  expose _medium _referencePressure
  use strict arg point,time=0
  numeric digits 40
  v=self~velocityAt(point,time)
  return _referencePressure+_medium~density*v~dot(v)/2
::method stateAt
  expose _medium
  use strict arg point,time=0
  return .FluidState~new(_medium,point,self~velocityAt(point,time),self~pressureAt(point,time),time)

::class FluidDynamics public
::method reynoldsNumber class
  use strict arg medium,speed,characteristicLength
  numeric digits 40
  speed=.FluidUnitBoundary~scalar(speed,.Units~metrePerSecond~dimension,'Reynolds speed')
  characteristicLength=.FluidUnitBoundary~scalar(characteristicLength,.UnitDimension~length,'Reynolds characteristic length')
  if speed<0 then raise syntax 88.900 array('non-negative Reynolds speed',speed)
  if characteristicLength<=0 then raise syntax 88.900 array('positive Reynolds characteristic length',characteristicLength)
  return medium~density*speed*characteristicLength/medium~dynamicViscosity
::method dynamicPressure class
  use strict arg medium,speed
  numeric digits 40
  speed=.FluidUnitBoundary~scalar(speed,.Units~metrePerSecond~dimension,'dynamic-pressure speed')
  if speed<0 then raise syntax 88.900 array('non-negative dynamic-pressure speed',speed)
  return medium~density*speed*speed/2
::method dynamicPressureQuantity class
  use strict arg medium,speed
  return .Units~q(self~dynamicPressure(medium,speed),.Units~pascal)

::class LaminarCircularPipeFlow public
::method init
  expose _medium _radius _length _pressureDrop _threshold
  use strict arg medium,radius,length,pressureDrop,referenceLaminarThreshold=2300
  radius=.FluidUnitBoundary~scalar(radius,.UnitDimension~length,'pipe radius')
  length=.FluidUnitBoundary~scalar(length,.UnitDimension~length,'pipe length')
  pressureDrop=.FluidUnitBoundary~scalar(pressureDrop,.Units~pascal~dimension,'pipe pressure drop')
  if radius<=0 then raise syntax 88.900 array('positive pipe radius',radius)
  if length<=0 then raise syntax 88.900 array('positive pipe length',length)
  if pressureDrop<0 then raise syntax 88.900 array('non-negative pressure drop',pressureDrop)
  if referenceLaminarThreshold<=0 then raise syntax 88.900 array('positive reference Reynolds threshold',referenceLaminarThreshold)
  _medium=medium; _radius=radius; _length=length; _pressureDrop=pressureDrop; _threshold=referenceLaminarThreshold
::method medium; expose _medium; return _medium
::method radius; expose _radius; return _radius
::method length; expose _length; return _length
::method pressureDrop; expose _pressureDrop; return _pressureDrop
::method referenceLaminarThreshold; expose _threshold; return _threshold
::method diameter; return 2*self~radius
::method area
  numeric digits 40
  pi=4*RxCalcArcTan(1,40,'R')
  return pi*self~radius*self~radius
::method volumeFlowRate
  numeric digits 40
  pi=4*RxCalcArcTan(1,40,'R')
  return pi*self~pressureDrop*self~radius**4/(8*self~medium~dynamicViscosity*self~length)
::method volumeFlowRateQuantity; return .Units~q(self~volumeFlowRate,.FluidUnitBoundary~volumetricFlowUnit)
::method massFlowRate
  numeric digits 40
  return self~medium~density*self~volumeFlowRate
::method massFlowRateQuantity; return .Units~q(self~massFlowRate,.FluidUnitBoundary~massFlowUnit)
::method meanVelocity
  numeric digits 40
  return self~volumeFlowRate/self~area
::method meanVelocityQuantity; return .Units~q(self~meanVelocity,.Units~metrePerSecond)
::method maximumVelocity
  numeric digits 40
  return 2*self~meanVelocity
::method maximumVelocityQuantity; return .Units~q(self~maximumVelocity,.Units~metrePerSecond)
::method velocityAtRadius
  use strict arg radialPosition
  numeric digits 40
  radialPosition=.FluidUnitBoundary~scalar(radialPosition,.UnitDimension~length,'pipe radial position')
  if radialPosition<0 | radialPosition>self~radius then raise syntax 88.900 array('radial position in pipe radius',radialPosition)
  return self~maximumVelocity*(1-(radialPosition/self~radius)**2)
::method velocityAtRadiusQuantity
  use strict arg radialPosition
  return .Units~q(self~velocityAtRadius(radialPosition),.Units~metrePerSecond)
::method reynoldsNumber
  return .FluidDynamics~reynoldsNumber(self~medium,self~meanVelocity,self~diameter)
::method laminarWithinReferenceRange; return self~reynoldsNumber<self~referenceLaminarThreshold
::method requireLaminar
  if \self~laminarWithinReferenceRange then -
    raise syntax 93.900 array('Hagen-Poiseuille laminar reference range; Reynolds='self~reynoldsNumber)
  return self
::method wallShearStress
  numeric digits 40
  return self~pressureDrop*self~radius/(2*self~length)
::method wallShearStressQuantity; return .Units~q(self~wallShearStress,.Units~pascal)
::method pressureGradient
  numeric digits 40
  return self~pressureDrop/self~length
::method pressureAtAxial
  use strict arg inletPressure,axialPosition
  numeric digits 40
  inletPressure=.FluidUnitBoundary~scalar(inletPressure,.Units~pascal~dimension,'pipe inlet pressure')
  axialPosition=.FluidUnitBoundary~scalar(axialPosition,.UnitDimension~length,'pipe axial position')
  if axialPosition<0 | axialPosition>self~length then raise syntax 88.900 array('axial position within pipe',axialPosition)
  return inletPressure-self~pressureDrop*(axialPosition/self~length)

::class FluidTracerSample public
::method init
  expose _time _position _state
  use strict arg time,position,state
  _time=time; _position=position; _state=state
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method position; expose _position; return _position
::method state; expose _state; return _state
::method velocity; return self~state~velocity
::method pressure; return self~state~pressure

::class FluidPathlineIntegrator public
::method init
  expose _field
  use strict arg field
  _field=field
::method field; expose _field; return _field
::method advance
  expose _field
  use strict arg position,time,dt
  time=.FluidUnitBoundary~scalar(time,.UnitDimension~time,'pathline time')
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'pathline timestep')
  if dt<=0 then raise syntax 88.900 array('positive pathline timestep',dt)
  k1=_field~velocityAt(position,time)
  k2=_field~velocityAt(position+k1*(dt/2),time+dt/2)
  k3=_field~velocityAt(position+k2*(dt/2),time+dt/2)
  k4=_field~velocityAt(position+k3*dt,time+dt)
  delta=(k1+k2*2+k3*2+k4)*(dt/6)
  return position+delta
::method trace
  expose _field
  use strict arg initialPosition,duration,dt,startTime=0
  duration=.FluidUnitBoundary~scalar(duration,.UnitDimension~time,'pathline duration')
  dt=.FluidUnitBoundary~scalar(dt,.UnitDimension~time,'pathline timestep')
  startTime=.FluidUnitBoundary~scalar(startTime,.UnitDimension~time,'pathline start time')
  if duration<0 then raise syntax 88.900 array('non-negative pathline duration',duration)
  if dt<=0 then raise syntax 88.900 array('positive pathline timestep',dt)
  samples=.array~new
  p=initialPosition; elapsed=0
  samples~append(.FluidTracerSample~new(startTime,p,_field~stateAt(p,startTime)))
  do while elapsed<duration
    step=dt
    if elapsed+step>duration then step=duration-elapsed
    if step<='0.000000000000001' then leave
    p=self~advance(p,startTime+elapsed,step)
    elapsed=elapsed+step
    samples~append(.FluidTracerSample~new(startTime+elapsed,p,_field~stateAt(p,startTime+elapsed)))
  end
  return samples

::class FluidProbe public
::method init
  expose _name _field _poseProvider
  use strict arg name,field,poseProvider
  _name=name; _field=field; _poseProvider=poseProvider
::method name; expose _name; return _name
::method field; expose _field; return _field
::method poseProvider; expose _poseProvider; return _poseProvider
::method position; return self~poseProvider~position
::method sample
  use strict arg time=0
  return self~field~stateAt(self~position,time)

::class FluidHydrodynamicProfile public
::method init
  expose _displacedVolume _dragArea _dragCoefficient _characteristicLength
  use strict arg displacedVolume,dragArea,dragCoefficient,characteristicLength
  displacedVolume=.FluidUnitBoundary~scalar(displacedVolume,.Units~cubicMetre~dimension,'displaced volume')
  dragArea=.FluidUnitBoundary~scalar(dragArea,.Units~squareMetre~dimension,'drag area')
  dragCoefficient=.FluidUnitBoundary~scalar(dragCoefficient,.UnitDimension~dimensionless,'drag coefficient')
  characteristicLength=.FluidUnitBoundary~scalar(characteristicLength,.UnitDimension~length,'hydrodynamic characteristic length')
  if displacedVolume<=0 then raise syntax 88.900 array('positive displaced volume',displacedVolume)
  if dragArea<=0 then raise syntax 88.900 array('positive drag area',dragArea)
  if dragCoefficient<0 then raise syntax 88.900 array('non-negative drag coefficient',dragCoefficient)
  if characteristicLength<=0 then raise syntax 88.900 array('positive hydrodynamic characteristic length',characteristicLength)
  _displacedVolume=displacedVolume; _dragArea=dragArea; _dragCoefficient=dragCoefficient; _characteristicLength=characteristicLength
::method displacedVolume; expose _displacedVolume; return _displacedVolume
::method dragArea; expose _dragArea; return _dragArea
::method dragCoefficient; expose _dragCoefficient; return _dragCoefficient
::method characteristicLength; expose _characteristicLength; return _characteristicLength
::method sphere class
  use strict arg radius,dragCoefficient
  numeric digits 40
  radius=.FluidUnitBoundary~scalar(radius,.UnitDimension~length,'hydrodynamic sphere radius')
  if radius<=0 then raise syntax 88.900 array('positive hydrodynamic sphere radius',radius)
  pi=4*RxCalcArcTan(1,40,'R')
  volume=4*pi*radius**3/3
  area=pi*radius*radius
  return self~new(volume,area,dragCoefficient,2*radius)

::class FluidForceReport public
::method init
  expose _buoyancy _drag _total _relativeVelocity _reynolds _state
  use strict arg buoyancy,drag,total,relativeVelocity,reynolds,state
  _buoyancy=buoyancy; _drag=drag; _total=total; _relativeVelocity=relativeVelocity; _reynolds=reynolds; _state=state
::method buoyancyForce; expose _buoyancy; return _buoyancy
::method dragForce; expose _drag; return _drag
::method totalForce; expose _total; return _total
::method relativeVelocity; expose _relativeVelocity; return _relativeVelocity
::method reynoldsNumber; expose _reynolds; return _reynolds
::method fluidState; expose _state; return _state
::method buoyancyMagnitudeQuantity; return .Units~q(self~buoyancyForce~norm,.Units~newton)
::method dragMagnitudeQuantity; return .Units~q(self~dragForce~norm,.Units~newton)
::method totalMagnitudeQuantity; return .Units~q(self~totalForce~norm,.Units~newton)

::class FullySubmergedFluidCoupling public
::method init
  expose _field _bodyState _profile _gravity
  use strict arg field,rigidBodyState,hydrodynamicProfile,gravity=.nil
  if gravity==.nil then gravity=.MathVector3~new(0,'-9.80665',0,rigidBodyState~body~pose~context)
  _field=field; _bodyState=rigidBodyState; _profile=hydrodynamicProfile; _gravity=gravity
::method field; expose _field; return _field
::method bodyState; expose _bodyState; return _bodyState
::method profile; expose _profile; return _profile
::method gravity; expose _gravity; return _gravity
::method forceReport
  expose _field _bodyState _profile _gravity
  use strict arg time=0
  numeric digits 40
  state=_field~stateAt(_bodyState~position,time)
  rho=state~medium~density
  buoyancy=_gravity*(-rho*_profile~displacedVolume)
  relative=state~velocity-_bodyState~velocity
  speed=relative~norm
  if speed<'0.000000000000001' | _profile~dragCoefficient=0 then -
    drag=.MathVector3~new(0,0,0,_bodyState~body~pose~context)
  else do
    magnitude=rho*_profile~dragCoefficient*_profile~dragArea*speed*speed/2
    drag=relative*(magnitude/speed)
  end
  reynolds=.FluidDynamics~reynoldsNumber(state~medium,speed,_profile~characteristicLength)
  total=buoyancy+drag
  return .FluidForceReport~new(buoyancy,drag,total,relative,reynolds,state)
::method apply
  use strict arg time=0
  report=self~forceReport(time)
  self~bodyState~applyForce(report~totalForce,self~bodyState~position)
  return report

::requires 'Mechanics.cls'
::requires 'rxmath' LIBRARY
