/* Rexx-tronics <-> ooRexx Physics World reciprocal electromechanical bridge v0.1-dev15.
 *
 * Authority split:
 *   Rexx-tronics owns electrical topology, sources, winding resistance/inductance,
 *   switching and terminal current/voltage.
 *   Physics owns rigid-body mechanics and the reciprocal F=K*i / e=K*v or
 *   tau=K*i / e=K*omega conversion law.
 *
 * PhysicsBackEmfSource is the electrical image of the ideal converter.  Put it
 * in series with ordinary Rexx-tronics R/L elements to model winding losses and
 * storage without hiding them inside Physics.
 */

::class PhysicsBackEmfSource subclass TwoTerminalComponent public
::attribute transducer get
::attribute lastCurrentAmps get
::attribute lastBackEmfVolts get
::attribute lastConversionPowerWatts get

::method init
  expose transducer lastCurrentAmps lastBackEmfVolts lastConversionPowerWatts
  use strict arg idArg, transducerArg
  self~init:super(idArg, 'PHYSICS_BACK_EMF_SOURCE', 'P', 'N')
  if \transducerArg~hasMethod('BACKEMF') | \transducerArg~hasMethod('BACKEMFQUANTITY') | \transducerArg~hasMethod('APPLYDRIVE') then -
      raise syntax 93.900 array('Physics back-EMF source requires a reciprocal Physics electromechanical transducer')
  transducer = transducerArg
  lastCurrentAmps = 0
  lastBackEmfVolts = 0
  lastConversionPowerWatts = 0

::method positive
  return self~pin('P')

::method negative
  return self~pin('N')

::method backEmf
  expose transducer
  return transducer~backEmfQuantity

::method backEmfVolts
  expose transducer
  numeric digits 50
  return transducer~backEmfQuantity~in(.Units~volt)

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method conversionElectricalPower
  expose lastConversionPowerWatts
  return .Units~q(lastConversionPowerWatts, .Units~watt)

::method dcExtraEquations
  return 1

::method transientExtraEquations
  return 1

::method dcStamp
  expose lastBackEmfVolts
  use strict arg context
  lastBackEmfVolts = self~backEmfVolts
  context~stampVoltageSource(self, self~positive, self~negative, lastBackEmfVolts)
  return .true

::method transientStamp
  expose lastBackEmfVolts
  use strict arg context, deltaSeconds, timePs
  lastBackEmfVolts = self~backEmfVolts
  context~stampVoltageSource(self, self~positive, self~negative, lastBackEmfVolts)
  return .true

::method dcUpdate
  expose lastCurrentAmps lastBackEmfVolts lastConversionPowerWatts
  use strict arg solution
  i = solution~current(self)
  if i == .nil then i = 0
  lastCurrentAmps = i
  lastBackEmfVolts = self~backEmfVolts
  lastConversionPowerWatts = lastBackEmfVolts * lastCurrentAmps
  solution~setPower(self, lastConversionPowerWatts)
  return .true

::method transientUpdate
  use strict arg solution, deltaSeconds, timePs
  return self~dcUpdate(solution)

::method electricalPathPeers
  use strict arg pin
  if pin == self~positive then return .array~of(self~negative)
  if pin == self~negative then return .array~of(self~positive)
  return .array~new


::class PhysicsElectromechanicalDriveBridge public
::attribute source get
::attribute transducer get
::attribute lastDrive get
::attribute lastActuation get

::method init
  expose source transducer lastDrive lastActuation
  use strict arg sourceArg, transducerArg=.nil
  if \sourceArg~isA(.PhysicsBackEmfSource) then raise syntax 93.900 array('electromechanical bridge source must be PhysicsBackEmfSource')
  source = sourceArg
  if transducerArg == .nil then transducer = source~transducer
  else transducer = transducerArg
  if transducer <> source~transducer then raise syntax 93.900 array('electromechanical bridge source/transducer mismatch')
  lastDrive = .nil
  lastActuation = .nil

::method applyFromSolution
  expose source transducer lastDrive lastActuation
  numeric digits 50
  use strict arg solution, timeArg, causeArg='Rexx-tronics electrical solve'
  current = solution~current(source)
  if current == .nil then raise syntax 93.900 array('electromechanical converter branch current is unavailable')
  vp = solution~voltage(source~positive~net)
  vn = solution~voltage(source~negative~net)
  if vp == .nil | vn == .nil then raise syntax 93.900 array('electromechanical converter terminal voltage is unavailable')
  voltage = vp - vn
  lastDrive = .ElectricalDriveObservation~new(.RexxTronicsUnits~typed(timeArg, .Units~second, 'electromechanical drive time'), .Units~q(current, .Units~ampere), .Units~q(voltage, .Units~volt), causeArg, source, solution)
  lastActuation = transducer~applyDrive(lastDrive)
  return lastActuation


::class ElectromechanicalCouplingStep public
::attribute startTimeSeconds get
::attribute endTimeSeconds get
::attribute preSolution get
::attribute postSolution get
::attribute actuationEvents get

::method init
  expose startTimeSeconds endTimeSeconds preSolution postSolution actuationEvents
  use strict arg startArg, endArg, preArg, postArg, eventsArg
  startTimeSeconds = startArg + 0
  endTimeSeconds = endArg + 0
  preSolution = preArg
  postSolution = postArg
  actuationEvents = eventsArg

::method startTime
  expose startTimeSeconds
  return .Units~q(startTimeSeconds, .Units~second)

::method endTime
  expose endTimeSeconds
  return .Units~q(endTimeSeconds, .Units~second)


/* Fixed-step staggered coupling for memoryless/quasi-static electrical networks.
 *
 * Each step:
 *   1. solve the present electrical network including current Physics back EMF;
 *   2. turn the solved converter current into typed Physics drive observations;
 *   3. advance Physics mechanics by dt;
 *   4. re-solve the electrical network against the new back EMF.
 *
 * Winding resistance is naturally represented by a Rexx-tronics Resistor.
 * Winding inductance can already be represented electrically, but this coupler
 * deliberately uses solveDC per partition and therefore does NOT claim coupled
 * winding-inductance dynamics yet.  That will require a persistent transient
 * stepper rather than silently resetting dynamic electrical history.
 */
::class QuasiStaticElectromechanicalCoupler public
::attribute circuit get
::attribute mechanicsSolver get
::attribute bridges get
::attribute clock get

::method init
  expose circuit mechanicsSolver bridges clock
  use strict arg circuitArg, mechanicsSolverArg, clockArg=.nil
  circuit = circuitArg
  mechanicsSolver = mechanicsSolverArg
  clock = clockArg
  bridges = .array~new

::method addBridge
  expose bridges
  use strict arg bridge
  if \bridge~isA(.PhysicsElectromechanicalDriveBridge) then raise syntax 93.900 array('expected PhysicsElectromechanicalDriveBridge')
  bridges~append(bridge)
  return bridge

::method assertClockAligned private
  expose mechanicsSolver clock
  if clock == .nil then return .true
  mechanicsPs = .RexxTronicsUnits~timePicoseconds(mechanicsSolver~timeQuantity)
  if clock~nowPs <> mechanicsPs then raise syntax 93.900 array('Rexx-tronics SimulationClock and Physics mechanics time are not aligned')
  return .true

::method step
  expose circuit mechanicsSolver bridges clock
  numeric digits 50
  use strict arg deltaTime
  dt = .RexxTronicsUnits~typed(deltaTime, .Units~second, 'electromechanical coupling timestep')
  if dt~canonicalValue <= 0 then raise syntax 93.900 array('electromechanical coupling timestep must be positive')
  self~assertClockAligned

  start = mechanicsSolver~time
  pre = circuit~solveDC
  events = .array~new
  do bridge over bridges
    events~append(bridge~applyFromSolution(pre, mechanicsSolver~timeQuantity, 'Rexx-tronics -> Physics electromechanical drive'))
  end

  mechanicsSolver~step(dt)
  if clock <> .nil then clock~runUntil(mechanicsSolver~timeQuantity)
  post = circuit~solveDC
  return .ElectromechanicalCouplingStep~new(start, mechanicsSolver~time, pre, post, events)



::class TransientElectromechanicalCouplingStep public
::attribute startTimeSeconds get
::attribute endTimeSeconds get
::attribute electricalSolution get
::attribute actuationEvents get
::attribute backEmfBefore get
::attribute backEmfAfter get

::method init
  expose startTimeSeconds endTimeSeconds electricalSolution actuationEvents backEmfBefore backEmfAfter
  use strict arg startArg, endArg, solutionArg, eventsArg, beforeArg, afterArg
  startTimeSeconds = startArg + 0
  endTimeSeconds = endArg + 0
  electricalSolution = solutionArg
  actuationEvents = eventsArg
  backEmfBefore = beforeArg
  backEmfAfter = afterArg

::method startTime
  expose startTimeSeconds
  return .Units~q(startTimeSeconds, .Units~second)

::method endTime
  expose endTimeSeconds
  return .Units~q(endTimeSeconds, .Units~second)


/* Persistent R/L/C electromechanical co-simulation.
 *
 * The electrical TransientSolver is initialized once and then stepped in
 * lock-step with Physics mechanics.  Capacitor voltage and inductor current
 * history therefore survive every partition boundary.
 *
 * Staggered first-order partition for [t, t+dt]:
 *   1. electrical backward-Euler step to t+dt using Physics back EMF at t;
 *   2. apply the solved end-step converter current to Physics;
 *   3. advance Physics mechanics by dt;
 *   4. retain the new reciprocal back EMF for the next electrical step.
 *
 * This is deliberately not advertised as a fully implicit iterative
 * electromechanical solve.  It is a deterministic, history-preserving
 * co-simulation boundary.  Smaller dt reduces partition lag; a future
 * rollback/corrector solver may iterate both domains inside one timestep.
 */
::class TransientElectromechanicalCoupler public
::attribute circuit get
::attribute mechanicsSolver get
::attribute bridges get
::attribute clock get
::attribute electricalStepper get
::attribute nominalStep get
::attribute stepCount get

::method init
  expose circuit mechanicsSolver bridges clock electricalStepper nominalStep stepCount initialized
  use strict arg circuitArg, mechanicsSolverArg, clockArg, nominalStepArg
  circuit = circuitArg
  mechanicsSolver = mechanicsSolverArg
  clock = clockArg
  nominalStep = .RexxTronicsUnits~typed(nominalStepArg, .Units~second, 'electromechanical transient timestep')
  if nominalStep~canonicalValue <= 0 then raise syntax 93.900 array('electromechanical transient timestep must be positive')
  bridges = .array~new
  electricalStepper = circuit~newTransientStepper(clock)
  stepCount = 0
  initialized = .false

::method addBridge
  expose bridges
  use strict arg bridge
  if \bridge~isA(.PhysicsElectromechanicalDriveBridge) then raise syntax 93.900 array('expected PhysicsElectromechanicalDriveBridge')
  bridges~append(bridge)
  return bridge

::method assertAligned private
  expose mechanicsSolver clock electricalStepper initialized
  mechanicsPs = .RexxTronicsUnits~timePicoseconds(mechanicsSolver~timeQuantity)
  if clock~nowPs <> mechanicsPs then raise syntax 93.900 array('Rexx-tronics SimulationClock and Physics mechanics time are not aligned')
  if initialized & electricalStepper~currentPs <> clock~nowPs then raise syntax 93.900 array('electrical transient history is not aligned with the shared simulation clock')
  return .true

::method begin
  expose electricalStepper nominalStep initialized
  if initialized then return electricalStepper~lastSolution
  self~assertAligned
  initial = electricalStepper~begin(nominalStep)
  initialized = .true
  return initial

::method step
  expose mechanicsSolver bridges clock electricalStepper nominalStep stepCount initialized
  numeric digits 50
  use strict arg deltaTime=.nil
  if deltaTime == .nil then dt = nominalStep
  else dt = .RexxTronicsUnits~typed(deltaTime, .Units~second, 'electromechanical transient timestep')
  if dt~canonicalValue <= 0 then raise syntax 93.900 array('electromechanical transient timestep must be positive')

  if \initialized then self~begin
  self~assertAligned
  startSeconds = mechanicsSolver~time

  before = .array~new
  do bridge over bridges
    before~append(bridge~source~backEmf)
  end

  /* The shared clock advances here so scheduled electrical events at the end
   * of this partition are observed by the electrical solve. */
  solution = electricalStepper~step(dt)
  endTime = clock~now~quantity

  events = .array~new
  do bridge over bridges
    events~append(bridge~applyFromSolution(solution, endTime, 'persistent transient Rexx-tronics -> Physics drive'))
  end

  mechanicsSolver~step(dt)

  /* Mechanics must land on the same simulation instant already reached by
   * the electrical clock.  New back EMF remains live on the source and is
   * consumed by the next electrical step without reinitialising history. */
  self~assertAligned
  after = .array~new
  do bridge over bridges
    after~append(bridge~source~backEmf)
  end

  stepCount += 1
  return .TransientElectromechanicalCouplingStep~new(startSeconds, mechanicsSolver~time, solution, events, before, after)

::method runFor
  expose nominalStep
  numeric digits 50
  use strict arg duration
  remainingPs = .RexxTronicsUnits~timePicoseconds(duration)
  if remainingPs <= 0 then raise syntax 93.900 array('electromechanical duration must be positive')
  stepPs = .RexxTronicsUnits~timePicoseconds(nominalStep)
  last = .nil
  do while remainingPs > 0
    actualPs = stepPs
    if actualPs > remainingPs then actualPs = remainingPs
    last = self~step(actualPs)
    remainingPs -= actualPs
  end
  return last

::method result
  expose electricalStepper
  return electricalStepper~result

::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsTime.cls'
::requires 'Electromechanics.cls'
