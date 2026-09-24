/* Rexx-tronics <-> ooRexx Physics free-surface sensor bridge v0.1-dev15.
 *
 * Physics owns the liquid free-surface state.  Rexx-tronics owns the sensor's
 * electrical transfer characteristic and the electrical network it drives.
 *
 * This module deliberately does not re-solve hydrostatics or infer a liquid
 * level from vessel acceleration.  Physics supplies the authoritative depth
 * of a selected RectangularTankSlosh2D cell; the electrical transducer maps
 * that physical quantity through an explicit calibration.
 */

::class FreeSurfaceDepthObservation public
::attribute depthMetres get
::attribute timeSeconds get
::attribute xCell get
::attribute zCell get
::attribute source get
::attribute cause get
::attribute evidence get

::method init
  expose depthMetres timeSeconds xCell zCell source cause evidence
  numeric digits 50
  use strict arg depthArg, timeArg, xCellArg, zCellArg, sourceArg=.nil, causeArg=.nil, evidenceArg=.nil
  depthMetres = .RexxTronicsUnits~canonical(depthArg, .Units~metre, 'free-surface depth observation')
  timeSeconds = .RexxTronicsUnits~canonical(timeArg, .Units~second, 'free-surface depth observation time')
  xCell = xCellArg + 0
  zCell = zCellArg + 0
  if depthMetres < 0 then raise syntax 93.900 array('free-surface depth must not be negative')
  source = sourceArg
  cause = causeArg
  evidence = evidenceArg

::method depth
  expose depthMetres
  return .Units~q(depthMetres, .Units~metre)

::method time
  expose timeSeconds
  return .Units~q(timeSeconds, .Units~second)


::class PhysicsFreeSurfaceDepthProbe2D public
::attribute sloshModel get
::attribute xCell get
::attribute zCell get
::attribute label get
::attribute lastObservation get

::method init
  expose sloshModel xCell zCell label lastObservation
  use strict arg sloshArg, xCellArg, zCellArg, labelArg='free-surface depth probe'
  if \sloshArg~isA(.RectangularTankSlosh2D) then raise syntax 93.900 array('free-surface depth probe requires Physics RectangularTankSlosh2D')
  xCell = xCellArg + 0
  zCell = zCellArg + 0
  /* Ask Physics for the cell once at construction so its own range guard is
   * authoritative.  Do not duplicate grid bounds here. */
  sloshArg~depthAtCell(xCell, zCell)
  sloshModel = sloshArg
  label = labelArg~string
  lastObservation = .nil

::method sample
  expose sloshModel xCell zCell label lastObservation
  numeric digits 50
  use strict arg causeArg='Physics 2-D free-surface sample'
  depth = sloshModel~depthAtCell(xCell, zCell)
  snapshot = sloshModel~snapshot
  lastObservation = .FreeSurfaceDepthObservation~new(.Units~q(depth, .Units~metre), sloshModel~timeQuantity, xCell, zCell, self, causeArg, snapshot)
  return lastObservation


/* Explicitly calibrated depth -> voltage transducer.
 *
 * This is a generic qualification component, not a claim about any particular
 * float, capacitive probe or pressure sensor.  Exact hardware definitions can
 * replace the linear curve with a part-number-specific transducer later.
 */
::class LinearLiquidLevelTransducer subclass TwoTerminalComponent public
::attribute minimumDepthMetres get
::attribute maximumDepthMetres get
::attribute minimumOutputVolts get
::attribute maximumOutputVolts get
::attribute rangePolicy get
::attribute lastDepthMetres get
::attribute lastOutputVolts get
::attribute lastObservation get

::method init
  expose minimumDepthMetres maximumDepthMetres minimumOutputVolts maximumOutputVolts rangePolicy lastDepthMetres lastOutputVolts lastObservation
  numeric digits 50
  use strict arg idArg, minimumDepthArg, maximumDepthArg, minimumOutputArg='0 V', maximumOutputArg='5 V', rangePolicyArg='ERROR'
  self~init:super(idArg, 'LIQUID_LEVEL_TRANSDUCER', 'OUT', 'REF')
  minimumDepthMetres = .RexxTronicsUnits~canonical(minimumDepthArg, .Units~metre, 'level-sensor minimum depth')
  maximumDepthMetres = .RexxTronicsUnits~canonical(maximumDepthArg, .Units~metre, 'level-sensor maximum depth')
  minimumOutputVolts = .RexxTronicsUnits~canonical(minimumOutputArg, .Units~volt, 'level-sensor minimum output')
  maximumOutputVolts = .RexxTronicsUnits~canonical(maximumOutputArg, .Units~volt, 'level-sensor maximum output')
  if minimumDepthMetres < 0 | maximumDepthMetres <= minimumDepthMetres then raise syntax 93.900 array('invalid liquid-level calibration depth range')
  rangePolicy = rangePolicyArg~string~upper
  if rangePolicy <> 'ERROR' & rangePolicy <> 'CLAMP' then raise syntax 93.900 array('liquid-level range policy must be ERROR or CLAMP')
  lastDepthMetres = minimumDepthMetres
  lastOutputVolts = minimumOutputVolts
  lastObservation = .nil

::method output
  return self~pin('OUT')

::method reference
  return self~pin('REF')

::method minimumDepth
  expose minimumDepthMetres
  return .Units~q(minimumDepthMetres, .Units~metre)

::method maximumDepth
  expose maximumDepthMetres
  return .Units~q(maximumDepthMetres, .Units~metre)

::method lastDepth
  expose lastDepthMetres
  return .Units~q(lastDepthMetres, .Units~metre)

::method outputVoltage
  expose lastOutputVolts
  return .Units~q(lastOutputVolts, .Units~volt)

::method voltageForDepth
  expose minimumDepthMetres maximumDepthMetres minimumOutputVolts maximumOutputVolts rangePolicy
  numeric digits 50
  use strict arg depthArg
  depth = .RexxTronicsUnits~canonical(depthArg, .Units~metre, 'liquid-level depth')
  if depth < minimumDepthMetres then do
    if rangePolicy = 'CLAMP' then depth = minimumDepthMetres
    else raise syntax 93.900 array('liquid level below calibrated sensor range')
  end
  if depth > maximumDepthMetres then do
    if rangePolicy = 'CLAMP' then depth = maximumDepthMetres
    else raise syntax 93.900 array('liquid level above calibrated sensor range')
  end
  fraction = (depth - minimumDepthMetres) / (maximumDepthMetres - minimumDepthMetres)
  return minimumOutputVolts + fraction * (maximumOutputVolts - minimumOutputVolts)

::method applyDepth
  expose lastDepthMetres lastOutputVolts lastObservation
  numeric digits 50
  use strict arg depthArg
  depth = .RexxTronicsUnits~canonical(depthArg, .Units~metre, 'liquid-level depth')
  lastOutputVolts = self~voltageForDepth(depth)
  lastDepthMetres = depth
  lastObservation = .nil
  return self

::method applyObservation
  expose lastDepthMetres lastOutputVolts lastObservation
  use strict arg observation
  if \observation~hasMethod('DEPTH') then raise syntax 93.900 array('liquid-level transducer observation must provide depth')
  value = self~voltageForDepth(observation~depth)
  lastDepthMetres = observation~depth~canonicalValue
  lastOutputVolts = value
  lastObservation = observation
  return self

::method dcExtraEquations
  return 1

::method transientExtraEquations
  return 1

::method dcStamp
  expose lastOutputVolts
  use strict arg context
  context~stampVoltageSource(self, self~output, self~reference, lastOutputVolts)
  return .true

::method transientStamp
  expose lastOutputVolts
  use strict arg context, deltaSeconds, timePs
  context~stampVoltageSource(self, self~output, self~reference, lastOutputVolts)
  return .true

::method dcUpdate
  use strict arg solution
  i = solution~current(self)
  if i == .nil then return .true
  vp = solution~voltage(self~output~net)
  vn = solution~voltage(self~reference~net)
  solution~setPower(self, (vp - vn) * i)
  return .true

::method electricalPathPeers
  use strict arg pin
  if pin == self~output then return .array~of(self~reference)
  if pin == self~reference then return .array~of(self~output)
  return .array~new


::class FreeSurfaceDepthSensorBinding public
::attribute probe get
::attribute transducer get
::attribute lastObservation get

::method init
  expose probe transducer lastObservation
  use strict arg probeArg, transducerArg
  if \probeArg~isA(.PhysicsFreeSurfaceDepthProbe2D) then raise syntax 93.900 array('free-surface sensor binding requires PhysicsFreeSurfaceDepthProbe2D')
  if \transducerArg~isA(.LinearLiquidLevelTransducer) then raise syntax 93.900 array('free-surface sensor binding requires LinearLiquidLevelTransducer')
  probe = probeArg
  transducer = transducerArg
  lastObservation = .nil

::method sampleAndApply
  expose probe transducer lastObservation
  use strict arg causeArg='Physics free-surface -> Rexx-tronics level sensor'
  lastObservation = probe~sample(causeArg)
  transducer~applyObservation(lastObservation)
  return lastObservation


::class FreeSurfaceElectricalCouplingStep2D public
::attribute startTimeSeconds get
::attribute endTimeSeconds get
::attribute electricalSolution get
::attribute observations get
::attribute physicsSnapshot get

::method init
  expose startTimeSeconds endTimeSeconds electricalSolution observations physicsSnapshot
  use strict arg startArg, endArg, solutionArg, observationsArg, snapshotArg
  startTimeSeconds = startArg + 0
  endTimeSeconds = endArg + 0
  electricalSolution = solutionArg
  observations = observationsArg
  physicsSnapshot = snapshotArg

::method startTime
  expose startTimeSeconds
  return .Units~q(startTimeSeconds, .Units~second)

::method endTime
  expose endTimeSeconds
  return .Units~q(endTimeSeconds, .Units~second)


/* Explicit staggered 2-D free-surface/electrical coupling.
 *
 * For [t,t+dt]:
 *   1. Physics advances its free surface to t+dt under caller-supplied
 *      vessel-frame effective gravity;
 *   2. each physical depth probe samples that t+dt state;
 *   3. calibrated electrical transducers accept those observations;
 *   4. the persistent electrical transient solver advances to the same t+dt.
 *
 * This preserves electrical C/L history and a common simulation-time endpoint.
 * It is intentionally not advertised as a monolithic fluid/electrical solve.
 */
::class FreeSurfaceElectricalCoupler2D public
::attribute sloshModel get
::attribute circuit get
::attribute clock get
::attribute electricalStepper get
::attribute nominalStep get
::attribute bindings get
::attribute stepCount get

::method init
  expose sloshModel circuit clock electricalStepper nominalStep bindings stepCount initialized
  use strict arg sloshArg, circuitArg, clockArg, nominalStepArg
  if \sloshArg~isA(.RectangularTankSlosh2D) then raise syntax 93.900 array('free-surface electrical coupler requires Physics RectangularTankSlosh2D')
  sloshModel = sloshArg
  circuit = circuitArg
  clock = clockArg
  nominalStep = .RexxTronicsUnits~typed(nominalStepArg, .Units~second, 'free-surface electrical coupling timestep')
  if nominalStep~canonicalValue <= 0 then raise syntax 93.900 array('free-surface electrical coupling timestep must be positive')
  electricalStepper = circuit~newTransientStepper(clock)
  bindings = .array~new
  stepCount = 0
  initialized = .false

::method addBinding
  expose bindings
  use strict arg binding
  if \binding~isA(.FreeSurfaceDepthSensorBinding) then raise syntax 93.900 array('expected FreeSurfaceDepthSensorBinding')
  bindings~append(binding)
  return binding

::method assertAligned private
  expose sloshModel clock electricalStepper initialized
  physicsPs = .RexxTronicsUnits~timePicoseconds(sloshModel~timeQuantity)
  if clock~nowPs <> physicsPs then raise syntax 93.900 array('Rexx-tronics SimulationClock and Physics free-surface time are not aligned')
  if initialized & electricalStepper~currentPs <> clock~nowPs then raise syntax 93.900 array('electrical transient history is not aligned with shared free-surface clock')
  return .true

::method sampleBindings private
  expose bindings
  use strict arg causeArg
  observations = .array~new
  do binding over bindings
    observations~append(binding~sampleAndApply(causeArg))
  end
  return observations

::method begin
  expose electricalStepper nominalStep initialized
  if initialized then return electricalStepper~lastSolution
  self~assertAligned
  self~sampleBindings('initial Physics free-surface state')
  initial = electricalStepper~begin(nominalStep)
  initialized = .true
  return initial

::method step
  expose sloshModel clock electricalStepper nominalStep stepCount initialized
  numeric digits 50
  use strict arg gravityXArg=0, gravityZArg=0, normalGravityArg=9.80665, deltaTime=.nil
  if deltaTime == .nil then dt = nominalStep
  else dt = .RexxTronicsUnits~typed(deltaTime, .Units~second, 'free-surface electrical coupling timestep')
  if dt~canonicalValue <= 0 then raise syntax 93.900 array('free-surface electrical coupling timestep must be positive')
  if \initialized then self~begin
  self~assertAligned

  startSeconds = sloshModel~time
  gx = .RexxTronicsUnits~canonical(gravityXArg, .Units~metrePerSecondSquared, '2-D free-surface x effective gravity')
  gz = .RexxTronicsUnits~canonical(gravityZArg, .Units~metrePerSecondSquared, '2-D free-surface z effective gravity')
  gn = .RexxTronicsUnits~canonical(normalGravityArg, .Units~metrePerSecondSquared, '2-D free-surface normal effective gravity')
  snapshot = sloshModel~step(dt, gx, gz, gn)
  observations = self~sampleBindings('Physics 2-D free-surface endpoint')

  solution = electricalStepper~step(dt)
  self~assertAligned
  stepCount += 1
  return .FreeSurfaceElectricalCouplingStep2D~new(startSeconds, sloshModel~time, solution, observations, snapshot)

::method runFor
  expose nominalStep
  numeric digits 50
  use strict arg durationArg, gravityXArg=0, gravityZArg=0, normalGravityArg=9.80665
  remainingPs = .RexxTronicsUnits~timePicoseconds(durationArg)
  if remainingPs <= 0 then raise syntax 93.900 array('free-surface electrical coupling duration must be positive')
  nominalPs = .RexxTronicsUnits~timePicoseconds(nominalStep)
  last = .nil
  do while remainingPs > 0
    actualPs = nominalPs
    if actualPs > remainingPs then actualPs = remainingPs
    last = self~step(gravityXArg, gravityZArg, normalGravityArg, actualPs)
    remainingPs -= actualPs
  end
  return last

::method result
  expose electricalStepper
  return electricalStepper~result

::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsTime.cls'
::requires 'FreeSurfaceFluids2D.cls'
