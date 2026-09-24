/* ooRexx Physics World v0.1-dev12
   Fracture-aware containment and conservative breach discharge.

   This is deliberately not general CFD.  It connects explicit containment
   topology to the existing rectangular 2-D free-surface model.  A breach is
   hydraulically active only after the containment boundary says it is open.
   Escaped liquid becomes retained EscapedFluidParcel evidence rather than
   disappearing from the simulation.

   The initial hydraulic law is a qualified sharp-opening/orifice relation:
       Q = Cd A_sub sqrt(2 g h_head)
   where Cd is explicit caller-supplied qualification data.
*/

::class FluidContainmentUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if value~isA(.UnitQuantity) then do
    if \value~dimension~compatible(expectedDimension) then -
      raise syntax 93.900 array(label 'has incompatible physical dimension')
    return value~canonicalValue+0
  end
  return value+0

::class RectangularBoundaryBreach2D public
::method init
  expose _id _side _coordinate _sill _height _width _cd _source
  use strict arg id,side,coordinate,sillElevation,openingHeight,openingWidth,dischargeCoefficient,source=.nil
  side=side~upper
  if side<>'LEFT' & side<>'RIGHT' & side<>'NEAR' & side<>'FAR' then -
    raise syntax 88.900 array('2D containment breach side LEFT RIGHT NEAR or FAR',side)
  _id=id; _side=side
  _coordinate=.FluidContainmentUnitBoundary~scalar(coordinate,.UnitDimension~length,'breach horizontal coordinate')
  _sill=.FluidContainmentUnitBoundary~scalar(sillElevation,.UnitDimension~length,'breach sill elevation')
  _height=.FluidContainmentUnitBoundary~scalar(openingHeight,.UnitDimension~length,'breach opening height')
  _width=.FluidContainmentUnitBoundary~scalar(openingWidth,.UnitDimension~length,'breach opening width')
  _cd=.FluidContainmentUnitBoundary~scalar(dischargeCoefficient,.UnitDimension~dimensionless,'breach discharge coefficient')
  if _sill<0 then raise syntax 88.900 array('non-negative breach sill elevation',_sill)
  if _height<=0 | _width<=0 then raise syntax 88.900 array('positive breach opening dimensions',_height _width)
  if _cd<=0 | _cd>1 then raise syntax 88.900 array('breach discharge coefficient in (0,1]',_cd)
  _source=source
::method id; expose _id; return _id
::method side; expose _side; return _side
::method coordinate; expose _coordinate; return _coordinate
::method sillElevation; expose _sill; return _sill
::method openingHeight; expose _height; return _height
::method openingWidth; expose _width; return _width
::method dischargeCoefficient; expose _cd; return _cd
::method source; expose _source; return _source
::method openingArea; return self~openingHeight*self~openingWidth
::method openingAreaQuantity; return .Units~q(self~openingArea,.Units~squareMetre)

::class FluidContainmentBoundary2D public
::method init
  expose _tank _breaches _state
  use strict arg tankGeometry
  _tank=tankGeometry; _breaches=.array~new; _state='CLOSED'
::method tank; expose _tank; return _tank
::method state; expose _state; return _state
::method isClosed; return self~state='CLOSED'
::method breaches; expose _breaches; return _breaches~copy
::method breachCount; expose _breaches; return _breaches~items
::method addBreach
  expose _tank _breaches _state
  use strict arg breach
  if breach~sillElevation>=_tank~height then raise syntax 88.900 array('breach sill below tank rim',breach~sillElevation _tank~height)
  if breach~sillElevation+breach~openingHeight>_tank~height then -
    raise syntax 88.900 array('breach opening contained by rectangular wall',breach~sillElevation breach~openingHeight _tank~height)
  if breach~side='LEFT' | breach~side='RIGHT' then do
    if abs(breach~coordinate)>_tank~width/2 then raise syntax 88.900 array('breach z coordinate on tank wall',breach~coordinate)
  end
  else if abs(breach~coordinate)>_tank~length/2 then raise syntax 88.900 array('breach x coordinate on tank wall',breach~coordinate)
  _breaches~append(breach); _state='BREACHED'
  return breach
::method markFragmented
  expose _state
  _state='FRAGMENTED'
  return self

::class EscapedFluidParcel public
::method init
  expose _medium _volume _mass _position _velocity _time _breach _source
  use strict arg medium,volume,positionLocal,velocityLocal,timeSeconds,breach,source=.nil
  _medium=medium; _volume=volume; _mass=medium~density*volume
  _position=positionLocal; _velocity=velocityLocal; _time=timeSeconds; _breach=breach; _source=source
::method medium; expose _medium; return _medium
::method volume; expose _volume; return _volume
::method volumeQuantity; return .Units~q(self~volume,.Units~cubicMetre)
::method mass; expose _mass; return _mass
::method massQuantity; return .Units~q(self~mass,.Units~kilogram)
::method positionLocal; expose _position; return _position
::method velocityLocal; expose _velocity; return _velocity
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method breach; expose _breach; return _breach
::method source; expose _source; return _source

::class BreachDischargeReport2D public
::method init
  expose _time _retainedVolume _retainedMass _escapedStep _escapedTotal _parcels
  use strict arg timeSeconds,retainedVolume,retainedMass,escapedStepVolume,escapedTotalVolume,parcels
  _time=timeSeconds; _retainedVolume=retainedVolume; _retainedMass=retainedMass
  _escapedStep=escapedStepVolume; _escapedTotal=escapedTotalVolume; _parcels=parcels~copy
::method time; expose _time; return _time
::method retainedVolume; expose _retainedVolume; return _retainedVolume
::method retainedMass; expose _retainedMass; return _retainedMass
::method escapedStepVolume; expose _escapedStep; return _escapedStep
::method escapedTotalVolume; expose _escapedTotal; return _escapedTotal
::method parcels; expose _parcels; return _parcels~copy

::class BreachedFreeSurfaceVessel2D public
::method init
  expose _slosh _boundary _parcels _initialVolume _initialMass _escapedVolume
  use strict arg sloshModel,containmentBoundary
  if sloshModel~tank<>containmentBoundary~tank then raise syntax 93.900 array('breach solver requires the same tank geometry authority as slosh model')
  _slosh=sloshModel; _boundary=containmentBoundary; _parcels=.array~new
  _initialVolume=sloshModel~currentVolume; _initialMass=sloshModel~currentMass; _escapedVolume=0
::method sloshModel; expose _slosh; return _slosh
::method boundary; expose _boundary; return _boundary
::method parcels; expose _parcels; return _parcels~copy
::method escapedVolume; expose _escapedVolume; return _escapedVolume
::method escapedMass
  expose _slosh _escapedVolume
  numeric digits 50
  return _slosh~medium~density*_escapedVolume
::method retainedVolume; expose _slosh; return _slosh~currentVolume
::method retainedMass; expose _slosh; return _slosh~currentMass
::method initialVolume; expose _initialVolume; return _initialVolume
::method initialMass; expose _initialMass; return _initialMass
::method massBalanceError
  numeric digits 50
  return self~initialMass-(self~retainedMass+self~escapedMass)
::method cellForBreach private
  expose _slosh
  use strict arg breach
  tank=_slosh~tank
  if breach~side='LEFT' | breach~side='RIGHT' then do
    j=trunc((breach~coordinate+tank~width/2)/tank~dz)+1
    if j<1 then j=1
    if j>tank~zCells then j=tank~zCells
    if breach~side='LEFT' then i=1
    else i=tank~xCells
  end
  else do
    i=trunc((breach~coordinate+tank~length/2)/tank~dx)+1
    if i<1 then i=1
    if i>tank~xCells then i=tank~xCells
    if breach~side='NEAR' then j=1
    else j=tank~zCells
  end
  return .array~of(i,j)
::method outwardDirection private
  use strict arg breach,context
  if breach~side='LEFT' then return .MathVector3~new(-1,0,0,context)
  if breach~side='RIGHT' then return .MathVector3~new(1,0,0,context)
  if breach~side='NEAR' then return .MathVector3~new(0,0,-1,context)
  return .MathVector3~new(0,0,1,context)
::method stepDischarge
  expose _slosh _boundary _parcels _escapedVolume
  use strict arg dt,normalEffectiveGravity='9.80665'
  numeric digits 50
  dt=.FluidContainmentUnitBoundary~scalar(dt,.UnitDimension~time,'breach discharge timestep')
  normalEffectiveGravity=.FluidContainmentUnitBoundary~scalar(normalEffectiveGravity,.Units~metrePerSecondSquared~dimension,'breach normal effective gravity')
  if dt<=0 then raise syntax 88.900 array('positive breach discharge timestep',dt)
  if normalEffectiveGravity<=0 then raise syntax 93.900 array('positive breach discharge gravity',normalEffectiveGravity)
  if _boundary~state='FRAGMENTED' then raise syntax 93.900 array('fragmented containment exceeds rectangular breached-vessel model')
  escapedStep=0; stepParcels=.array~new
  do breach over _boundary~breaches
    cell=self~cellForBreach(breach); i=cell[1]; j=cell[2]
    depth=_slosh~depthAtCell(i,j)
    head=depth-breach~sillElevation
    if head<=0 then iterate
    submerged=head
    if submerged>breach~openingHeight then submerged=breach~openingHeight
    area=breach~openingWidth*submerged
    speed=RxCalcSqrt(2*normalEffectiveGravity*head,40)
    requested=breach~dischargeCoefficient*area*speed*dt
    removed=_slosh~drainVolumeFromCell(i,j,requested)
    if removed<=0 then iterate
    context=.Maths~defaultContext
    x=_slosh~tank~xCentre(i); z=_slosh~tank~zCentre(j); y=breach~sillElevation+submerged/2
    position=.MathVector3~new(x,y,z,context)
    velocity=self~outwardDirection(breach,context)*speed
    parcel=.EscapedFluidParcel~new(_slosh~medium,removed,position,velocity,_slosh~time,breach,self)
    _parcels~append(parcel); stepParcels~append(parcel)
    _escapedVolume=_escapedVolume+removed; escapedStep=escapedStep+removed
  end
  return .BreachDischargeReport2D~new(_slosh~time,_slosh~currentVolume,_slosh~currentMass,escapedStep,_escapedVolume,stepParcels)
::method advance
  expose _slosh
  use strict arg dt,effectiveGravityX=0,effectiveGravityZ=0,normalEffectiveGravity='9.80665'
  _slosh~step(dt,effectiveGravityX,effectiveGravityZ,normalEffectiveGravity)
  return self~stepDischarge(dt,normalEffectiveGravity)

::class FractureContainmentBinding2D public
::method init
  expose _boundary _bindings
  use strict arg containmentBoundary
  _boundary=containmentBoundary; _bindings=.array~new
::method bindLink
  expose _bindings
  use strict arg deformableLink,breach
  _bindings~append(.array~of(deformableLink,breach,.false))
  return self
::method consume
  expose _boundary _bindings
  use strict arg fractureEvents
  opened=.array~new
  do event over fractureEvents
    do binding over _bindings
      if binding[3] then iterate
      if event~link==binding[1] then do
        _boundary~addBreach(binding[2]); binding[3]=.true; opened~append(binding[2])
      end
    end
  end
  return opened

::requires 'FreeSurfaceFluids2D.cls'
::requires 'Fracture.cls'
::requires 'rxmath' LIBRARY
