/* Rexx-tronics Physics fracture/electrical continuity bridge v0.1-dev15.
 *
 * Physics World remains authoritative for deformation, fracture criteria,
 * contact, fracture time/evidence, and post-fracture topology. Rexx-tronics
 * remains authoritative for electrical connectivity, current, voltage and
 * dissipation. This bridge makes a Physics DeformableLink an electrical
 * conductor whose circuit path opens when that physical load path fractures.
 *
 * The intact resistance is explicit electrical evidence. No attempt is made
 * here to derive resistivity, necking, contact arcing or post-fracture air-gap
 * breakdown from mechanics alone.
 */

::class PhysicsFractureConductor subclass TwoTerminalComponent public
::attribute physicsLink get
::attribute intactResistanceOhms get
::attribute brokenResistanceOhms get
::attribute lastCurrentAmps get
::attribute lastPowerWatts get
::attribute lastFractureEvent get

::method init
  expose physicsLink intactResistanceOhms brokenResistanceOhms lastCurrentAmps lastPowerWatts lastFractureEvent
  numeric digits 50
  use strict arg idArg, physicsLinkArg, intactResistanceArg='0.01 ohm', brokenResistanceArg='1000000000000 ohm'
  self~init:super(idArg, 'PHYSICS_FRACTURE_CONDUCTOR', 'A', 'B')
  if physicsLinkArg == .nil | \physicsLinkArg~hasMethod('BROKEN') then -
    raise syntax 93.900 array('PhysicsFractureConductor requires a Physics DeformableLink-like object exposing broken')
  physicsLink = physicsLinkArg
  intactResistanceOhms = .RexxTronicsUnits~canonical(intactResistanceArg, .Units~ohm, 'intact fracture-conductor resistance')
  brokenResistanceOhms = .RexxTronicsUnits~canonical(brokenResistanceArg, .Units~ohm, 'broken fracture-conductor resistance')
  if intactResistanceOhms <= 0 then raise syntax 93.900 array('intact fracture-conductor resistance must be positive')
  if brokenResistanceOhms <= intactResistanceOhms then raise syntax 93.900 array('broken fracture-conductor resistance must exceed intact resistance')
  lastCurrentAmps = 0
  lastPowerWatts = 0
  lastFractureEvent = .nil

::method fractured
  expose physicsLink
  return physicsLink~broken

::method state
  if self~fractured then return 'OPEN_FRACTURE'
  return 'INTACT'

::method intactResistance
  expose intactResistanceOhms
  return .Units~q(intactResistanceOhms, .Units~ohm)

::method brokenResistance
  expose brokenResistanceOhms
  return .Units~q(brokenResistanceOhms, .Units~ohm)

::method effectiveResistance
  expose intactResistanceOhms brokenResistanceOhms
  if self~fractured then return brokenResistanceOhms
  return intactResistanceOhms

::method resistance
  return .Units~q(self~effectiveResistance, .Units~ohm)

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method fractureCriterion
  expose physicsLink lastFractureEvent
  if lastFractureEvent <> .nil then return lastFractureEvent~criterion
  if physicsLink~hasMethod('FRACTURECRITERION') then return physicsLink~fractureCriterion
  return ''

::method fractureTime
  expose lastFractureEvent
  if lastFractureEvent == .nil then return .nil
  return lastFractureEvent~timeQuantity

::method fractureStress
  expose physicsLink lastFractureEvent
  if lastFractureEvent <> .nil then return lastFractureEvent~stressQuantity
  if self~fractured & physicsLink~hasMethod('FRACTURESTRESSQUANTITY') then return physicsLink~fractureStressQuantity
  return .nil

::method fractureEnergy
  expose physicsLink lastFractureEvent
  if lastFractureEvent <> .nil then return lastFractureEvent~releasedEnergyQuantity
  if self~fractured & physicsLink~hasMethod('FRACTUREENERGYQUANTITY') then return physicsLink~fractureEnergyQuantity
  return .nil

::method unresolvedFractureEnergy
  expose physicsLink lastFractureEvent
  if lastFractureEvent <> .nil then return lastFractureEvent~unresolvedReleasedEnergyQuantity
  if self~fractured & physicsLink~hasMethod('UNRESOLVEDFRACTUREENERGYQUANTITY') then return physicsLink~unresolvedFractureEnergyQuantity
  return .nil

/* Capture the retained Physics event which corresponds to this conductor's
 * physical link. Electrical behaviour itself is derived directly from the
 * authoritative link~broken state, so event capture is provenance, not a
 * second source of truth.
 */
::method captureFractureEvidence
  expose physicsLink lastFractureEvent
  use strict arg physicsSolver
  if physicsSolver == .nil | \physicsSolver~hasMethod('FRACTUREEVENTS') then -
    raise syntax 93.900 array('fracture evidence source must expose fractureEvents')
  events = physicsSolver~fractureEvents
  do event over events
    if event~link == physicsLink then do
      lastFractureEvent = event
      return event
    end
  end
  return .nil

::method electricalPathPeers
  use strict arg pin
  if self~fractured then return .array~new
  return self~electricalPathPeers:super(pin)

::method dcStamp
  use strict arg context
  context~stampConductance(self~pin('A'), self~pin('B'), 1 / self~effectiveResistance)
  return .true

::method dcUpdate
  expose lastCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution
  va = solution~voltage(self~pin('A')~net)
  vb = solution~voltage(self~pin('B')~net)
  lastCurrentAmps = (va - vb) / self~effectiveResistance
  lastPowerWatts = (va - vb) * lastCurrentAmps
  solution~setCurrent(self, lastCurrentAmps)
  solution~setPower(self, lastPowerWatts)
  return .true


::class FractureElectricalCouplingStep public
::attribute startTimePs get
::attribute endTimePs get
::attribute electricalSolution get
::attribute contactEvents get
::attribute fractureEvents get

::method init
  expose startTimePs endTimePs electricalSolution contactEvents fractureEvents
  use strict arg startArg, endArg, solutionArg, contactEventsArg, fractureEventsArg
  startTimePs = .RexxTronicsUnits~timePicoseconds(startArg)
  endTimePs = .RexxTronicsUnits~timePicoseconds(endArg)
  electricalSolution = solutionArg
  contactEvents = contactEventsArg~copy
  fractureEvents = fractureEventsArg~copy

::method startTime
  expose startTimePs
  return .Units~q(startTimePs / .SimTime~PS_PER_S, .Units~second)

::method endTime
  expose endTimePs
  return .Units~q(endTimePs / .SimTime~PS_PER_S, .Units~second)


/* One-way structural-failure -> electrical-continuity co-simulation.
 * Physics is stepped first over each partition, fracture state/evidence is
 * sampled, then the persistent electrical solver advances to the same end
 * instant. This is intentional: the component models a conductor whose
 * mechanical failure affects the circuit; electrical self-heating, Lorentz
 * force, arcing and electro-migration are separate couplings and are not
 * silently inferred here.
 */
::class FractureElectricalCoupler public
::attribute clock get
::attribute circuit get
::attribute physicsSolver get
::attribute stepCount get

::method init
  expose clock circuit physicsSolver stepper conductors begun stepCount nominalStepPs
  use strict arg circuitArg, physicsSolverArg, clockArg
  circuit = circuitArg
  physicsSolver = physicsSolverArg
  clock = clockArg
  if physicsSolver == .nil | \physicsSolver~hasMethod('STEP') | \physicsSolver~hasMethod('TIME') then -
    raise syntax 93.900 array('FractureElectricalCoupler requires a Physics deformable solver exposing step/time')
  stepper = circuit~newTransientStepper(clock)
  conductors = .array~new
  begun = .false
  stepCount = 0
  nominalStepPs = .nil
  self~assertAligned

::method addConductor
  expose conductors
  use strict arg conductor
  if conductor == .nil | \conductor~hasMethod('CAPTUREFRACTUREEVIDENCE') then -
    raise syntax 93.900 array('fracture coupler conductor must expose captureFractureEvidence')
  conductors~append(conductor)
  return conductor

::method assertAligned private
  expose clock physicsSolver
  numeric digits 50
  physicsPs = (physicsSolver~time * .SimTime~PS_PER_S)~round
  if abs(physicsPs - clock~nowPs) > 1 then -
    raise syntax 93.900 array('Physics deformable solver and Rexx-tronics SimulationClock are not aligned')
  return .true

::method begin
  expose stepper begun nominalStepPs
  use strict arg nominalStep
  if begun then raise syntax 93.900 array('fracture/electrical coupler is already initialized')
  nominalStepPs = .RexxTronicsUnits~timePicoseconds(nominalStep)
  if nominalStepPs <= 0 then raise syntax 93.900 array('fracture/electrical nominal step must be positive')
  self~assertAligned
  initial = stepper~begin(nominalStepPs)
  begun = .true
  return initial

::method step
  expose clock physicsSolver stepper conductors begun stepCount nominalStepPs
  numeric digits 50
  use strict arg deltaTime=.nil
  if deltaTime == .nil then do
    if nominalStepPs == .nil then raise syntax 93.900 array('first fracture/electrical step requires a timestep or begin()')
    deltaPs = nominalStepPs
  end
  else deltaPs = .RexxTronicsUnits~timePicoseconds(deltaTime)
  if deltaPs <= 0 then raise syntax 93.900 array('fracture/electrical timestep must be positive')
  if \begun then self~begin(deltaPs)
  self~assertAligned
  startPs = clock~nowPs
  deltaSeconds = deltaPs / .SimTime~PS_PER_S

  physicsSolver~step(.Units~q(deltaSeconds, .Units~second))
  fractureEvents = physicsSolver~fractureEvents
  contactEvents = physicsSolver~contactEvents
  do conductor over conductors
    conductor~captureFractureEvidence(physicsSolver)
  end

  solution = stepper~step(deltaPs)
  stepCount += 1
  self~assertAligned
  return .FractureElectricalCouplingStep~new(startPs, clock~nowPs, solution, contactEvents, fractureEvents)

::method runFor
  expose nominalStepPs
  numeric digits 50
  use strict arg duration, step=.nil
  durationPs = .RexxTronicsUnits~timePicoseconds(duration)
  if durationPs <= 0 then raise syntax 93.900 array('fracture/electrical duration must be positive')
  if step == .nil then do
    if nominalStepPs == .nil then raise syntax 93.900 array('runFor requires a step before coupler initialization')
    stepPs = nominalStepPs
  end
  else stepPs = .RexxTronicsUnits~timePicoseconds(step)
  remaining = durationPs
  last = .nil
  do while remaining > 0
    actual = stepPs
    if actual > remaining then actual = remaining
    last = self~step(actual)
    remaining -= actual
  end
  return last

::method result
  expose stepper
  return stepper~result

::requires 'RexxTronicsDC.cls'
