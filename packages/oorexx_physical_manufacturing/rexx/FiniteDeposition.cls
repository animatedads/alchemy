/* Physical Manufacturing dev6: finite-duration deposition.
   A deposition command is sampled while the physical machine continues to
   move.  The retained bead path is therefore evidence of actual relative
   nozzle/workpiece motion, not a reconstruction from commanded coordinates. */

::class DepositionPathSample public
::method init
  expose _time _coordinate _mass
  use strict arg timeSeconds,coordinate,massIncrement
  if massIncrement<0 then raise syntax 88.900 array('non-negative deposited mass')
  _time=timeSeconds; _coordinate=coordinate; _mass=massIncrement
::method time; expose _time; return _time
::method coordinate; expose _coordinate; return _coordinate
::method massIncrement; expose _mass; return _mass

::class DepositedBead public
::method init
  expose _id _samples _material _startTime _endTime
  use strict arg beadId,samples,materialDefinition,startTime,endTime
  if samples==.nil | samples~items<1 then raise syntax 88.900 array('deposition requires at least one physical sample')
  if endTime<=startTime then raise syntax 88.900 array('positive deposition interval')
  _id=beadId~string; _samples=samples~copy; _material=materialDefinition
  _startTime=startTime; _endTime=endTime
::method id; expose _id; return _id
::method samples; expose _samples; return _samples~copy
::method material; expose _material; return _material
::method startTime; expose _startTime; return _startTime
::method endTime; expose _endTime; return _endTime
::method duration; expose _startTime _endTime; return _endTime-_startTime
::method mass
  expose _samples
  total=0; do s over _samples; total=total+s~massIncrement; end; return total
::method firstCoordinate; expose _samples; return _samples[1]~coordinate
::method lastCoordinate; expose _samples; return _samples[_samples~items]~coordinate
::method pathSpan; return self~lastCoordinate-self~firstCoordinate
::method centroidCoordinate
  expose _samples
  m=0; weighted=0
  do s over _samples
    m=m+s~massIncrement; weighted=weighted+s~coordinate*s~massIncrement
  end
  if m<=0 then raise syntax 88.900 array('positive deposited bead mass')
  return weighted/m
::method minCoordinate
  expose _samples
  v=_samples[1]~coordinate; do s over _samples; if s~coordinate<v then v=s~coordinate; end; return v
::method maxCoordinate
  expose _samples
  v=_samples[1]~coordinate; do s over _samples; if s~coordinate>v then v=s~coordinate; end; return v

::class FiniteDepositionProcess public
::method init
  expose _printer _thermalProcess _beads
  use strict arg printerDynamics,thermalDepositionProcess
  _printer=printerDynamics; _thermalProcess=thermalDepositionProcess; _beads=.array~new
::method beads; expose _beads; return _beads~copy
::method depositFor
  expose _printer _thermalProcess _beads
  use strict arg id,duration,dt,totalMass,width,height,depth,baseStiffness,damping,initialTemperature,lateralOffset=0
  if duration<=0 | dt<=0 | totalMass<=0 then raise syntax 88.900 array('positive duration, timestep and deposited mass')
  startTime=_thermalProcess~thermalSolver~time
  samples=.array~new; elapsed=0; deposited=0
  do while elapsed<duration
    h=dt; if elapsed+h>duration then h=duration-elapsed
    coordinate=_thermalProcess~step(h)
    dm=totalMass*h/duration
    if elapsed+h>=duration then dm=totalMass-deposited
    deposited=deposited+dm
    samples~append(.DepositionPathSample~new(startTime+elapsed+h,coordinate,dm))
    elapsed=elapsed+h
  end
  bead=.DepositedBead~new(id,samples,_thermalProcess~sections~at(1)~materialRef,startTime,startTime+duration)
  /* Commit the resulting manufactured section at the mass-weighted physical
     bead centroid. lateralOffset is relative to the current top-section frame. */
  section=_thermalProcess~depositSection(id,totalMass,width,height,depth,baseStiffness,damping,initialTemperature,lateralOffset+bead~centroidCoordinate)
  _beads~append(bead)
  return bead

::requires 'ThermalDeposition.cls'
