/* Physical Manufacturing dev7: resolved finite bead geometry.
   A finite extrusion is retained as material-bearing path elements.  Element
   geometry comes from successive actual nozzle/workpiece coordinates while
   extrusion is occurring.  Nominal feed length is retained only as command
   evidence; it never overwrites the resolved physical path. */

::class DepositedPathElement public
::method init
  expose _id _t0 _t1 _x0 _x1 _mass _nominalLength _material _temperature
  use strict arg elementId,startTime,endTime,startCoordinate,endCoordinate,mass,nominalLength,materialDefinition=.nil,temperatureKelvin=.nil
  if endTime<=startTime then raise syntax 88.900 array('positive deposited-element duration')
  if mass<=0 then raise syntax 88.900 array('positive deposited-element mass')
  if nominalLength<=0 then raise syntax 88.900 array('positive nominal feed length')
  _id=elementId~string; _t0=startTime; _t1=endTime
  _x0=startCoordinate; _x1=endCoordinate; _mass=mass; _nominalLength=nominalLength
  _material=materialDefinition; _temperature=temperatureKelvin
::method id; expose _id; return _id
::method startTime; expose _t0; return _t0
::method endTime; expose _t1; return _t1
::method duration; expose _t0 _t1; return _t1-_t0
::method startCoordinate; expose _x0; return _x0
::method endCoordinate; expose _x1; return _x1
::method midpoint; expose _x0 _x1; return (_x0+_x1)/2
::method mass; expose _mass; return _mass
::method material; expose _material; return _material
::method temperatureKelvin; expose _temperature; return _temperature
::method nominalLength; expose _nominalLength; return _nominalLength
::method signedLength; expose _x0 _x1; return _x1-_x0
::method actualLength; return abs(self~signedLength)
::method stretchRatio; expose _nominalLength; return self~actualLength/_nominalLength
::method lineDensity
  l=self~actualLength
  if l=0 then return .nil       /* material deposited while locally stationary */
  return self~mass/l
::method direction
  d=self~signedLength
  if d>0 then return 1
  if d<0 then return -1
  return 0

::class ResolvedDepositedBead public
::method init
  expose _id _elements _material
  use strict arg beadId,elements,materialDefinition=.nil
  if elements==.nil | elements~items<1 then raise syntax 88.900 array('resolved bead requires elements')
  _id=beadId~string; _elements=elements~copy; _material=materialDefinition
::method id; expose _id; return _id
::method elements; expose _elements; return _elements~copy
::method elementCount; expose _elements; return _elements~items
::method material; expose _material; return _material
::method mass
  expose _elements
  total=0; do e over _elements; total=total+e~mass; end; return total
::method actualPathLength
  expose _elements
  total=0; do e over _elements; total=total+e~actualLength; end; return total
::method nominalPathLength
  expose _elements
  total=0; do e over _elements; total=total+e~nominalLength; end; return total
::method massWeightedCoordinate
  expose _elements
  total=0; weighted=0
  do e over _elements; total=total+e~mass; weighted=weighted+e~mass*e~midpoint; end
  return weighted/total
::method minCoordinate
  expose _elements
  v=_elements[1]~startCoordinate
  do e over _elements
    if e~startCoordinate<v then v=e~startCoordinate
    if e~endCoordinate<v then v=e~endCoordinate
  end
  return v
::method maxCoordinate
  expose _elements
  v=_elements[1]~startCoordinate
  do e over _elements
    if e~startCoordinate>v then v=e~startCoordinate
    if e~endCoordinate>v then v=e~endCoordinate
  end
  return v
::method reversalCount
  expose _elements
  count=0; prior=0
  do e over _elements
    d=e~direction
    if d<>0 then do
      if prior<>0 then do
        if d<>prior then count=count+1
      end
      prior=d
    end
  end
  return count

::class SegmentedDepositionBuilder public
/* Pure evidence builder used by live deposition and qualification.  Samples are
   actual relative coordinates.  Mass and nominal-feed increments are explicit
   so local stretching/compression is observed rather than guessed. */
::method init
  expose _id _material _elements _lastTime _lastCoordinate _counter
  use strict arg beadId,startTime,startCoordinate,materialDefinition=.nil
  _id=beadId~string; _material=materialDefinition; _elements=.array~new
  _lastTime=startTime; _lastCoordinate=startCoordinate; _counter=0
::method append
  expose _id _material _elements _lastTime _lastCoordinate _counter
  use strict arg timeSeconds,coordinate,massIncrement,nominalLengthIncrement,temperatureKelvin=.nil
  _counter=_counter+1
  e=.DepositedPathElement~new(_id||'-'||_counter,_lastTime,timeSeconds,_lastCoordinate,coordinate,massIncrement,nominalLengthIncrement,_material,temperatureKelvin)
  _elements~append(e); _lastTime=timeSeconds; _lastCoordinate=coordinate
  return e
::method finish
  expose _id _material _elements
  return .ResolvedDepositedBead~new(_id,_elements,_material)

::class SegmentedFiniteDepositionProcess public
/* Live machine bridge.  The machine advances before each element endpoint is
   observed.  feedLength is the controller-requested material path length for
   the whole interval; actual element lengths come only from physical motion. */
::method init
  expose _printer _thermalProcess _beads
  use strict arg printerDynamics,thermalDepositionProcess
  _printer=printerDynamics; _thermalProcess=thermalDepositionProcess; _beads=.array~new
::method beads; expose _beads; return _beads~copy
::method depositFor
  expose _printer _thermalProcess _beads
  use strict arg id,duration,dt,totalMass,feedLength,width,height,depth,baseStiffness,damping,initialTemperature,lateralOffset=0
  if duration<=0 | dt<=0 | totalMass<=0 | feedLength<=0 then raise syntax 88.900 array('positive duration, timestep, mass and feed length')
  startTime=_thermalProcess~thermalSolver~time
  builder=.SegmentedDepositionBuilder~new(id,startTime,_printer~depositionPosition,_thermalProcess~sections~at(1)~materialRef)
  elapsed=0; deposited=0; fed=0
  do while elapsed<duration
    h=dt; if elapsed+h>duration then h=duration-elapsed
    coordinate=_thermalProcess~step(h)
    dm=totalMass*h/duration; dl=feedLength*h/duration
    if elapsed+h>=duration then do; dm=totalMass-deposited; dl=feedLength-fed; end
    deposited=deposited+dm; fed=fed+dl
    builder~append(startTime+elapsed+h,coordinate,dm,dl,initialTemperature)
    elapsed=elapsed+h
  end
  bead=builder~finish
  /* The current reduced-order mechanics still commits one thermal section at
     the bead mass centroid.  The complete element path is retained so a later
     deformable-material solver can consume it without reconstructing geometry. */
  _thermalProcess~depositSection(id,totalMass,width,height,depth,baseStiffness,damping,initialTemperature,lateralOffset+bead~massWeightedCoordinate)
  _beads~append(bead)
  return bead

::requires 'FiniteDeposition.cls'
