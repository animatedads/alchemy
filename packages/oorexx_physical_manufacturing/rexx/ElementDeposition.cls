/* Physical Manufacturing dev8: deposited path elements become physical workpiece sections.
   This removes dev7's single-centroid mechanical reduction. Each finite deposition
   interval is committed as its own mass-bearing Physics mechanics body and thermal node.
   The retained commanded path remains evidence only; actual resolved motion determines
   element placement. */

::class ElementResolvedDepositionProcess public
::method init
  expose _printer _thermalProcess _beads _sectionGroups
  use strict arg printerDynamics,thermalDepositionProcess
  _printer=printerDynamics; _thermalProcess=thermalDepositionProcess
  _beads=.array~new; _sectionGroups=.array~new
::method beads; expose _beads; return _beads~copy
::method sectionGroups; expose _sectionGroups; return _sectionGroups~copy
::method depositFor
  expose _printer _thermalProcess _beads _sectionGroups
  use strict arg id,duration,dt,totalMass,feedLength,beadWidth,beadHeight,beadDepth,baseStiffness,damping,initialTemperature,lateralOffset=0
  if duration<=0 | dt<=0 | totalMass<=0 | feedLength<=0 then raise syntax 88.900 array('positive duration, timestep, mass and feed length')
  if beadWidth<=0 | beadHeight<=0 | beadDepth<=0 then raise syntax 88.900 array('positive bead dimensions')
  startTime=_thermalProcess~thermalSolver~time
  material=.nil
  existing=_thermalProcess~sections
  if existing~items>0 then material=existing[1]~materialRef
  builder=.SegmentedDepositionBuilder~new(id,startTime,_printer~depositionPosition,material)
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
  group=.array~new
  previousMid=0
  first=.true
  index=0
  do e over bead~elements
    index=index+1
    /* The physical box has a nonzero transverse width even when relative motion
       is locally stationary. Actual path length is never invented: it remains
       on DepositedPathElement; beadWidth is the declared process cross-section. */
    physicalWidth=beadWidth
    if e~actualLength>physicalWidth then physicalWidth=e~actualLength
    if first then do
      dx=lateralOffset+e~midpoint
      first=.false
    end
    else dx=e~midpoint-previousMid
    previousMid=e~midpoint
    s=_thermalProcess~depositSection(id||'-e'||index,e~mass,physicalWidth,beadHeight,beadDepth,baseStiffness,damping,initialTemperature,dx)
    group~append(s)
  end
  _beads~append(bead); _sectionGroups~append(group)
  return bead

::requires 'SegmentedDeposition.cls'
