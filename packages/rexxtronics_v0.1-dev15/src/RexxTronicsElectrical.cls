/* Rexx-tronics electrical topology and transition history v0.1-dev15 */

::class ElectricalTransition public
::attribute timePs get
::attribute voltage get
::attribute source get
::attribute cause get

::method init
  expose timePs voltage source cause
  numeric digits 50
  use strict arg timeArg, voltageArg, sourceArg=.nil, causeArg=.nil
  timePs = .RexxTronicsUnits~timePicoseconds(timeArg)
  voltage = .RexxTronicsUnits~canonical(voltageArg, .Units~volt, 'transition voltage')
  source = sourceArg
  cause = causeArg


::class Pin public
::attribute number get
::attribute name get
::attribute role get
::attribute electricalType get
::attribute net get
::attribute owner get

::method init
  expose number name role electricalType net owner
  numeric digits 50
  use strict arg numberArg, nameArg, roleArg='SIGNAL', electricalTypeArg='PASSIVE', ownerArg=.nil
  number = numberArg
  name = nameArg~string
  role = roleArg~string~upper
  electricalType = electricalTypeArg~string~upper
  owner = ownerArg
  net = .nil

::method attachNet
  expose net
  numeric digits 50
  use strict arg netArg
  if net <> .nil & net <> netArg then raise syntax 93.900 array('pin is already attached to another net')
  net = netArg
  return self

::method voltage
  expose net
  numeric digits 50
  if net == .nil then return .nil
  return net~voltage

::method voltageQuantity
  expose net
  if net == .nil then return .nil
  return net~voltageQuantity

::method qualifiedName
  expose owner name
  if owner == .nil then return name
  if owner~hasMethod('ID') then return owner~id || '.' || name
  return name

::method string
  return self~qualifiedName


::class ElectricalNet public
::attribute name get
::attribute voltage get
::attribute transitions get
::attribute participants get
::attribute ground get

::method init
  expose name voltage transitions participants ground
  numeric digits 50
  use strict arg nameArg, initialVoltage=0, groundArg=.false
  name = nameArg~string
  voltage = .RexxTronicsUnits~canonical(initialVoltage, .Units~volt, 'initial net voltage')
  ground = groundArg
  transitions = .array~new
  participants = .array~new
  transitions~append(.ElectricalTransition~new(0, voltage, .nil, 'initial'))

::method connect
  expose participants
  numeric digits 50
  use strict arg pin
  do existing over participants
    if existing == pin then return self
  end
  participants~append(pin)
  pin~attachNet(self)
  return self

::method drive
  expose voltage transitions
  numeric digits 50
  use strict arg atTime, sourcePin, newVoltage, cause=.nil
  atPs = .RexxTronicsUnits~timePicoseconds(atTime)
  newVoltage = .RexxTronicsUnits~canonical(newVoltage, .Units~volt, 'net drive voltage')
  if transitions~items > 0 then do
    last = transitions[transitions~items]
    if atPs < last~timePs then raise syntax 93.900 array('net transitions must be monotonic in simulation time')
  end
  if newVoltage = voltage then return .false
  voltage = newVoltage
  transitions~append(.ElectricalTransition~new(atPs, voltage, sourcePin, cause))
  return .true

::method setDCVoltage
  expose voltage
  numeric digits 50
  use strict arg newVoltage
  voltage = .RexxTronicsUnits~canonical(newVoltage, .Units~volt, 'DC net voltage')
  return voltage

::method voltageQuantity
  expose voltage
  return .Units~q(voltage, .Units~volt)

::method voltageAt
  expose transitions
  numeric digits 50
  use strict arg when
  targetPs = .RexxTronicsUnits~timePicoseconds(when)
  value = transitions[1]~voltage
  do tr over transitions
    if tr~timePs > targetPs then leave
    value = tr~voltage
  end
  return value

::method voltageAtQuantity
  use strict arg when
  return .Units~q(self~voltageAt(when), .Units~volt)

::method transitionCount
  expose transitions
  numeric digits 50
  return transitions~items


::class TopologyIssue public
::attribute severity get
::attribute code get
::attribute text get
::attribute subject get

::method init
  expose severity code text subject
  use strict arg severityArg, codeArg, textArg, subjectArg=.nil
  severity = severityArg~string~upper
  code = codeArg~string~upper
  text = textArg~string
  subject = subjectArg

::method string
  expose severity code text
  return severity || ' ' || code || ': ' || text


::class TopologyReport public
::attribute issues get

::method init
  expose issues
  issues = .array~new

::method add
  expose issues
  use strict arg severity, code, text, subject=.nil
  issues~append(.TopologyIssue~new(severity, code, text, subject))
  return self

::method ok
  expose issues
  do issue over issues
    if issue~severity = 'ERROR' then return .false
  end
  return .true

::method errorCount
  expose issues
  count = 0
  do issue over issues
    if issue~severity = 'ERROR' then count += 1
  end
  return count

::method warningCount
  expose issues
  count = 0
  do issue over issues
    if issue~severity = 'WARNING' then count += 1
  end
  return count


::class Circuit public
::attribute nets get
::attribute pins get
::attribute components get
::attribute lastDCResult get
::attribute lastTransientResult get

::method init
  expose nets pins components lastDCResult lastTransientResult
  numeric digits 50
  nets = .directory~new
  pins = .directory~new
  components = .directory~new
  lastDCResult = .nil
  lastTransientResult = .nil
  nets['GND'] = .ElectricalNet~new('GND', 0, .true)

::method net
  expose nets
  numeric digits 50
  use strict arg name
  key = name~string~upper
  if \nets~hasIndex(key) then nets[key] = .ElectricalNet~new(name)
  return nets[key]

::method ground
  expose nets
  return nets['GND']

::method registerPin
  expose pins
  numeric digits 50
  use strict arg componentName, pin
  key = componentName~string~upper || '.' || pin~name~upper
  if pins~hasIndex(key) then raise syntax 93.900 array('duplicate circuit pin ' || key)
  pins[key] = pin
  return pin

::method add
  expose components
  use strict arg component
  key = component~id~upper
  if components~hasIndex(key) then raise syntax 93.900 array('duplicate circuit component ' || component~id)
  components[key] = component
  component~attachCircuit(self)
  do p over component~pins
    self~registerPin(component~id, p)
  end
  return component

::method component
  expose components
  use strict arg id
  key = id~string~upper
  if \components~hasIndex(key) then return .nil
  return components[key]

::method connect
  use strict arg netName, pinsArray
  n = self~net(netName)
  if pinsArray~isA(.Pin) then do
    n~connect(pinsArray)
    return n
  end
  do p over pinsArray
    n~connect(p)
  end
  return n

::method connectGround
  use strict arg pin
  self~ground~connect(pin)
  return self~ground

::method validateTopology
  expose components
  report = .TopologyReport~new
  do key over components
    c = components[key]
    do p over c~pins
      if p~net == .nil then report~add('ERROR', 'UNCONNECTED_PIN', 'unconnected pin ' || p~qualifiedName, p)
    end
  end
  return report

::method tracePath
  use strict arg fromPin, toPin
  if fromPin == toPin then return .array~of(fromPin~qualifiedName)

  workQueue = .queue~new
  seen = .identityTable~new
  previous = .identityTable~new
  workQueue~queue(fromPin)
  seen[fromPin] = .true
  found = .false

  do while workQueue~items > 0
    p = workQueue~pull
    if p == toPin then do
      found = .true
      leave
    end

    neighbors = .array~new
    if p~net <> .nil then do np over p~net~participants
      if np <> p then neighbors~append(np)
    end

    if p~owner <> .nil & p~owner~hasMethod('ELECTRICALPATHPEERS') then do
      peers = p~owner~electricalPathPeers(p)
      do np over peers
        neighbors~append(np)
      end
    end

    do np over neighbors
      if \seen~hasIndex(np) then do
        seen[np] = .true
        previous[np] = p
        workQueue~queue(np)
      end
    end
  end

  if \found then return .array~new

  reverse = .array~new
  p = toPin
  do forever
    reverse~append(p~qualifiedName)
    if p == fromPin then leave
    p = previous[p]
  end

  pathArray = .array~new
  do i = reverse~items to 1 by -1
    pathArray~append(reverse[i])
  end
  return pathArray

::method hasElectricalPath
  use strict arg fromPin, toPin
  return self~tracePath(fromPin, toPin)~items > 0

::method solveDC
  expose lastDCResult
  solver = .DCSolver~new(self)
  lastDCResult = solver~solve
  return lastDCResult

::method simulateTransient
  expose lastTransientResult
  use strict arg clock, duration, step
  solver = .TransientSolver~new(self, clock)
  lastTransientResult = solver~solve(duration, step)
  return lastTransientResult

/* Persistent transient solver for interleaved multi-domain co-simulation. */
::method newTransientStepper
  use strict arg clock
  return .TransientSolver~new(self, clock)

::class DCSolution public
::attribute converged get
::attribute iterations get
::attribute residual get
::attribute topologyReport get

::method init
  expose converged iterations residual topologyReport nodeVoltages branchCurrents powers
  use strict arg convergedArg=.false, iterationsArg=0, residualArg=0, topologyArg=.nil
  converged = convergedArg
  iterations = iterationsArg
  residual = residualArg
  topologyReport = topologyArg
  nodeVoltages = .directory~new
  branchCurrents = .directory~new
  powers = .directory~new

::method markConverged
  expose converged iterations residual
  use strict arg iterationsArg, residualArg=0
  converged = .true
  iterations = iterationsArg + 0
  residual = residualArg + 0
  return self

::method componentKey private
  use strict arg componentOrId
  if componentOrId~hasMethod('ID') then return componentOrId~id~upper
  return componentOrId~string~upper

::method netKey private
  use strict arg netOrName
  if netOrName~isA(.ElectricalNet) then return netOrName~name~upper
  return netOrName~string~upper

::method setVoltage
  expose nodeVoltages
  use strict arg netOrName, volts
  key = self~netKey(netOrName)
  value = .RexxTronicsUnits~canonical(volts, .Units~volt, 'solution voltage')
  nodeVoltages[key] = value
  return value

::method voltage
  expose nodeVoltages
  use strict arg netOrName
  key = self~netKey(netOrName)
  if \nodeVoltages~hasIndex(key) then return .nil
  return nodeVoltages[key]

::method voltageQuantity
  use strict arg netOrName, displayUnit=.nil
  value = self~voltage(netOrName)
  if value == .nil then return .nil
  if displayUnit == .nil then return .Units~q(value, .Units~volt)
  return .Units~q(value, .Units~volt, displayUnit)

::method setCurrent
  expose branchCurrents
  use strict arg componentOrId, amps
  key = self~componentKey(componentOrId)
  value = .RexxTronicsUnits~canonical(amps, .Units~ampere, 'solution current')
  branchCurrents[key] = value
  return value

::method current
  expose branchCurrents
  use strict arg componentOrId
  key = self~componentKey(componentOrId)
  if \branchCurrents~hasIndex(key) then return .nil
  return branchCurrents[key]

::method currentQuantity
  use strict arg componentOrId, displayUnit=.nil
  value = self~current(componentOrId)
  if value == .nil then return .nil
  if displayUnit == .nil then return .Units~q(value, .Units~ampere)
  return .Units~q(value, .Units~ampere, displayUnit)

::method setPower
  expose powers
  use strict arg componentOrId, watts
  key = self~componentKey(componentOrId)
  value = .RexxTronicsUnits~canonical(watts, .Units~watt, 'solution power')
  powers[key] = value
  return value

::method power
  expose powers
  use strict arg componentOrId
  key = self~componentKey(componentOrId)
  if \powers~hasIndex(key) then return .nil
  return powers[key]

::method powerQuantity
  use strict arg componentOrId, displayUnit=.nil
  value = self~power(componentOrId)
  if value == .nil then return .nil
  if displayUnit == .nil then return .Units~q(value, .Units~watt)
  return .Units~q(value, .Units~watt, displayUnit)

::method voltages
  expose nodeVoltages
  return nodeVoltages~copy

::method currents
  expose branchCurrents
  return branchCurrents~copy

::method powers
  expose powers
  return powers~copy


::class DCStampContext public
::attribute matrix get
::attribute rhs get
::attribute nodeIndex get
::attribute extraIndex get

::method init
  expose matrix rhs nodeIndex extraIndex
  use strict arg matrixArg, rhsArg, nodeIndexArg, extraIndexArg
  matrix = matrixArg
  rhs = rhsArg
  nodeIndex = nodeIndexArg
  extraIndex = extraIndexArg

::method node
  expose nodeIndex
  use strict arg pin
  if pin~net == .nil then raise syntax 93.900 array('unconnected pin ' || pin~qualifiedName)
  if pin~net~ground then return 0
  key = pin~net~name~upper
  if \nodeIndex~hasIndex(key) then raise syntax 93.900 array('unknown DC node ' || key)
  return nodeIndex[key]

::method addA
  expose matrix
  numeric digits 50
  use strict arg row, col, value
  if row = 0 | col = 0 then return
  matrix[row][col] = matrix[row][col] + value

::method addZ
  expose rhs
  numeric digits 50
  use strict arg row, value
  if row = 0 then return
  rhs[row] = rhs[row] + value

::method stampConductance
  numeric digits 50
  use strict arg pinA, pinB, conductance
  a = self~node(pinA)
  b = self~node(pinB)
  if conductance~isA(.UnitQuantity) then g = conductance~in(.Units~siemens)
  else g = conductance + 0
  self~addA(a, a, g)
  self~addA(b, b, g)
  self~addA(a, b, -g)
  self~addA(b, a, -g)

::method stampCurrent
  numeric digits 50
  use strict arg pinFrom, pinTo, amps
  a = self~node(pinFrom)
  b = self~node(pinTo)
  i = .RexxTronicsUnits~canonical(amps, .Units~ampere, 'stamped current')
  self~addZ(a, -i)
  self~addZ(b, i)

/* Voltage-controlled current source.  Positive transconductance means a
 * current from outputFrom -> outputTo of gm * (VcontrolPositive -
 * VcontrolNegative).  This is the primitive needed by compact transistor,
 * op-amp and other controlled-source models without introducing hidden
 * voltage sources or a second solver.
 */
::method stampVCCS
  numeric digits 50
  use strict arg outputFrom, outputTo, controlPositive, controlNegative, transconductance
  of = self~node(outputFrom)
  ot = self~node(outputTo)
  cp = self~node(controlPositive)
  cn = self~node(controlNegative)
  if transconductance~isA(.UnitQuantity) then gm = transconductance~in(.Units~siemens)
  else gm = transconductance + 0
  self~addA(of, cp, gm)
  self~addA(of, cn, -gm)
  self~addA(ot, cp, -gm)
  self~addA(ot, cn, gm)

::method stampVoltageSource
  expose extraIndex
  numeric digits 50
  use strict arg component, pinPositive, pinNegative, volts
  key = component~id~upper
  if \extraIndex~hasIndex(key) then raise syntax 93.900 array('no MNA equation allocated for voltage source ' || component~id)
  k = extraIndex[key]
  p = self~node(pinPositive)
  n = self~node(pinNegative)
  self~addA(p, k, 1)
  self~addA(n, k, -1)
  self~addA(k, p, 1)
  self~addA(k, n, -1)
  self~addZ(k, .RexxTronicsUnits~canonical(volts, .Units~volt, 'stamped voltage'))


::class DCSolver public
::method init
  expose circuit
  use strict arg circuitArg
  circuit = circuitArg

::method solve
  expose circuit
  numeric digits 50

  topology = circuit~validateTopology
  if \topology~ok then raise syntax 93.900 array('DC solve refused: circuit has ' || topology~errorCount || ' topology error(s)')

  nodeIndex = .directory~new
  nodeNames = .array~new
  nextNode = 1

  nets = circuit~nets
  do key over nets
    n = nets[key]
    if \n~ground & n~participants~items > 0 then do
      nodeKey = n~name~upper
      nodeIndex[nodeKey] = nextNode
      nodeNames[nextNode] = nodeKey
      nextNode += 1
    end
  end
  nodeCount = nextNode - 1

  extraIndex = .directory~new
  extraCount = 0
  components = circuit~components
  do key over components
    c = components[key]
    count = c~dcExtraEquations
    if count > 1 then raise syntax 93.900 array('v0.1-dev15 supports at most one extra DC equation per component')
    if count = 1 then do
      extraCount += 1
      extraIndex[c~id~upper] = nodeCount + extraCount
    end
  end

  size = nodeCount + extraCount
  if size = 0 then raise syntax 93.900 array('DC solve has no equations')

  maxIterations = 50
  do iteration = 1 to maxIterations
    matrix = .array~new(size)
    rhs = .array~new(size)
    do row = 1 to size
      matrix[row] = .array~new(size)
      rhs[row] = 0
      do col = 1 to size
        matrix[row][col] = 0
      end
    end

    context = .DCStampContext~new(matrix, rhs, nodeIndex, extraIndex)
    do key over components
      components[key]~dcStamp(context)
    end

    values = self~gaussianSolve(matrix, rhs)
    solution = .DCSolution~new(.false, iteration, 0, topology)
    solution~setVoltage('GND', 0)
    circuit~ground~setDCVoltage(0)

    do i = 1 to nodeCount
      nodeName = nodeNames[i]
      solution~setVoltage(nodeName, values[i])
      circuit~net(nodeName)~setDCVoltage(values[i])
    end

    do key over extraIndex
      componentId = key
      solution~setCurrent(componentId, values[extraIndex[key]])
    end

    rebuild = .false
    do key over components
      if components[key]~dcNeedsResolve(solution) then rebuild = .true
    end
    if rebuild then iterate

    do key over components
      components[key]~dcUpdate(solution)
    end
    solution~markConverged(iteration, 0)
    return solution
  end

  raise syntax 93.900 array('DC nonlinear solve did not converge after ' || maxIterations || ' iterations')

::method gaussianSolve private
  numeric digits 50
  use strict arg matrix, rhs
  n = rhs~items
  a = .array~new(n)
  b = .array~new(n)

  do i = 1 to n
    a[i] = matrix[i]~copy
    b[i] = rhs[i]
  end

  do k = 1 to n
    pivot = k
    maxValue = abs(a[k][k])
    do row = k + 1 to n
      v = abs(a[row][k])
      if v > maxValue then do
        maxValue = v
        pivot = row
      end
    end

    if maxValue < 1e-30 then raise syntax 93.900 array('singular or floating DC network at equation ' || k)

    if pivot <> k then do
      tempRow = a[k]
      a[k] = a[pivot]
      a[pivot] = tempRow
      tempValue = b[k]
      b[k] = b[pivot]
      b[pivot] = tempValue
    end

    pivotValue = a[k][k]
    do col = k to n
      a[k][col] = a[k][col] / pivotValue
    end
    b[k] = b[k] / pivotValue

    do row = 1 to n
      if row <> k then do
        factor = a[row][k]
        if factor <> 0 then do
          do col = k to n
            a[row][col] = a[row][col] - factor * a[k][col]
          end
          b[row] = b[row] - factor * b[k]
        end
      end
    end
  end

  return b


::class TransientPoint public
::attribute timePs get
::attribute solution get

::method init
  expose timePs solution
  use strict arg timeArg, solutionArg
  timePs = .RexxTronicsUnits~timePicoseconds(timeArg)
  solution = solutionArg


::class TransientResult public
::attribute points get
::attribute startTimePs get
::attribute endTimePs get
::attribute stepPs get

::method init
  expose points startTimePs endTimePs stepPs
  use strict arg startArg, stepArg
  startTimePs = .RexxTronicsUnits~timePicoseconds(startArg)
  stepPs = .RexxTronicsUnits~timePicoseconds(stepArg)
  endTimePs = startTimePs
  points = .array~new

::method addPoint
  expose points endTimePs
  use strict arg point
  if points~items > 0 then do
    last = points[points~items]
    if point~timePs <= last~timePs then raise syntax 93.900 array('transient points must be strictly increasing')
  end
  points~append(point)
  endTimePs = point~timePs
  return point

::method pointCount
  expose points
  return points~items

::method voltageAt
  expose points
  numeric digits 50
  use strict arg netOrName, when
  if points~items = 0 then return .nil
  target = .RexxTronicsUnits~timePicoseconds(when)

  first = points[1]
  if target <= first~timePs then return first~solution~voltage(netOrName)
  last = points[points~items]
  if target >= last~timePs then return last~solution~voltage(netOrName)

  previous = first
  do i = 2 to points~items
    current = points[i]
    if target = current~timePs then return current~solution~voltage(netOrName)
    if target < current~timePs then do
      v0 = previous~solution~voltage(netOrName)
      v1 = current~solution~voltage(netOrName)
      fraction = (target - previous~timePs) / (current~timePs - previous~timePs)
      return v0 + fraction * (v1 - v0)
    end
    previous = current
  end
  return last~solution~voltage(netOrName)

::method currentAt
  expose points
  numeric digits 50
  use strict arg componentOrId, when
  if points~items = 0 then return .nil
  target = .RexxTronicsUnits~timePicoseconds(when)

  first = points[1]
  if target <= first~timePs then return first~solution~current(componentOrId)
  last = points[points~items]
  if target >= last~timePs then return last~solution~current(componentOrId)

  previous = first
  do i = 2 to points~items
    current = points[i]
    if target = current~timePs then return current~solution~current(componentOrId)
    if target < current~timePs then do
      i0 = previous~solution~current(componentOrId)
      i1 = current~solution~current(componentOrId)
      if i0 == .nil | i1 == .nil then return .nil
      fraction = (target - previous~timePs) / (current~timePs - previous~timePs)
      return i0 + fraction * (i1 - i0)
    end
    previous = current
  end
  return last~solution~current(componentOrId)

::method voltageAtQuantity
  use strict arg netOrName, when, displayUnit=.nil
  value = self~voltageAt(netOrName, when)
  if value == .nil then return .nil
  if displayUnit == .nil then return .Units~q(value, .Units~volt)
  return .Units~q(value, .Units~volt, displayUnit)

::method currentAtQuantity
  use strict arg componentOrId, when, displayUnit=.nil
  value = self~currentAt(componentOrId, when)
  if value == .nil then return .nil
  if displayUnit == .nil then return .Units~q(value, .Units~ampere)
  return .Units~q(value, .Units~ampere, displayUnit)

::method signal
  use strict arg netOrName
  return .TransientNetSignal~new(self, netOrName)


::class TransientNetSignal public
::method init
  expose result netOrName
  use strict arg resultArg, netArg
  result = resultArg
  netOrName = netArg

::method voltageAt
  expose result netOrName
  use strict arg when
  return result~voltageAt(netOrName, when)


::class TransientSolver public
::attribute initialized get
::attribute currentPs get
::attribute lastSolution get
::attribute transientRun get

::method init
  expose circuit clock initialized topology currentPs lastSolution transientRun nominalStepPs
  use strict arg circuitArg, clockArg
  circuit = circuitArg
  clock = clockArg
  initialized = .false
  topology = .nil
  currentPs = clock~nowPs
  lastSolution = .nil
  transientRun = .nil
  nominalStepPs = .nil

/* Establish the transient operating state exactly once.  Dynamic components
 * retain their history across every subsequent step() call.  This is the
 * persistent boundary required by cross-domain co-simulation: a coupler may
 * interleave one electrical step with one Physics mechanics step without
 * reinitialising capacitors or inductors.
 */
::method begin
  expose circuit clock initialized topology currentPs lastSolution transientRun nominalStepPs
  numeric digits 50
  use strict arg nominalStep
  if initialized then raise syntax 93.900 array('transient solver is already initialized')

  nominalStepPs = .RexxTronicsUnits~timePicoseconds(nominalStep)
  if nominalStepPs <= 0 then raise syntax 93.900 array('transient step must be positive')

  topology = circuit~validateTopology
  if \topology~ok then raise syntax 93.900 array('transient solve refused: circuit has ' || topology~errorCount || ' topology error(s)')

  currentPs = clock~nowPs
  initial = circuit~solveDC
  components = circuit~components
  do key over components
    components[key]~transientInitialize(initial)
  end

  transientRun = .TransientResult~new(currentPs, nominalStepPs)
  transientRun~addPoint(.TransientPoint~new(currentPs, initial))
  lastSolution = initial
  initialized = .true
  return initial

::method assertClockAligned private
  expose clock currentPs
  if clock~nowPs <> currentPs then raise syntax 93.900 array('persistent transient solver and SimulationClock are not aligned')
  return .true

/* Advance by one electrical interval while preserving C/L history. */
::method step
  expose circuit clock initialized topology currentPs lastSolution transientRun
  numeric digits 50
  use strict arg deltaTime
  deltaPs = .RexxTronicsUnits~timePicoseconds(deltaTime)
  if deltaPs <= 0 then raise syntax 93.900 array('transient time step must be positive')
  if \initialized then self~begin(deltaTime)
  self~assertClockAligned

  nextPs = currentPs + deltaPs
  deltaSeconds = deltaPs / .SimTime~PS_PER_S

  /* Discrete scheduled events share the same authoritative simulation clock. */
  clock~runUntil(nextPs)

  solution = self~solveStep(deltaSeconds, nextPs, topology)
  transientRun~addPoint(.TransientPoint~new(nextPs, solution))
  currentPs = nextPs
  lastSolution = solution
  return solution

/* Advance an already-started (or fresh) solver through a duration. */
::method advance
  expose initialized currentPs transientRun
  numeric digits 50
  use strict arg duration, step
  durationPs = .RexxTronicsUnits~timePicoseconds(duration)
  stepPs = .RexxTronicsUnits~timePicoseconds(step)
  if durationPs <= 0 then raise syntax 93.900 array('transient duration must be positive')
  if stepPs <= 0 then raise syntax 93.900 array('transient step must be positive')
  if \initialized then self~begin(step)

  finishPs = currentPs + durationPs
  do while currentPs < finishPs
    actualPs = stepPs
    if currentPs + actualPs > finishPs then actualPs = finishPs - currentPs
    self~step(actualPs)
  end
  return transientRun

/* Compatibility one-shot facade. */
::method solve
  expose initialized
  use strict arg duration, step
  if initialized then raise syntax 93.900 array('solve() requires a fresh transient solver; use advance() on an initialized solver')
  self~begin(step)
  return self~advance(duration, step)

::method result
  expose transientRun
  return transientRun

::method solveStep private
  expose circuit
  numeric digits 50
  use strict arg deltaSeconds, timePs, topology

  nodeIndex = .directory~new
  nodeNames = .array~new
  nextNode = 1
  nets = circuit~nets
  do key over nets
    n = nets[key]
    if \n~ground & n~participants~items > 0 then do
      nodeKey = n~name~upper
      nodeIndex[nodeKey] = nextNode
      nodeNames[nextNode] = nodeKey
      nextNode += 1
    end
  end
  nodeCount = nextNode - 1

  extraIndex = .directory~new
  extraCount = 0
  components = circuit~components
  do key over components
    c = components[key]
    count = c~transientExtraEquations
    if count > 1 then raise syntax 93.900 array('v0.1-dev15 supports at most one extra transient equation per component')
    if count = 1 then do
      extraCount += 1
      extraIndex[c~id~upper] = nodeCount + extraCount
    end
  end

  size = nodeCount + extraCount
  if size = 0 then raise syntax 93.900 array('transient solve has no equations')

  maxIterations = 50
  do iteration = 1 to maxIterations
    matrix = .array~new(size)
    rhs = .array~new(size)
    do row = 1 to size
      matrix[row] = .array~new(size)
      rhs[row] = 0
      do col = 1 to size
        matrix[row][col] = 0
      end
    end

    context = .DCStampContext~new(matrix, rhs, nodeIndex, extraIndex)
    do key over components
      components[key]~transientStamp(context, deltaSeconds, timePs)
    end

    values = self~gaussianSolve(matrix, rhs)
    solution = .DCSolution~new(.false, iteration, 0, topology)
    solution~setVoltage('GND', 0)
    circuit~ground~setDCVoltage(0)

    do i = 1 to nodeCount
      nodeName = nodeNames[i]
      solution~setVoltage(nodeName, values[i])
      circuit~net(nodeName)~setDCVoltage(values[i])
    end

    do key over extraIndex
      solution~setCurrent(key, values[extraIndex[key]])
    end

    rebuild = .false
    do key over components
      if components[key]~transientNeedsResolve(solution, deltaSeconds, timePs) then rebuild = .true
    end
    if rebuild then iterate

    /* History is committed once, only after the nonlinear trial converges. */
    do key over components
      components[key]~transientUpdate(solution, deltaSeconds, timePs)
    end

    solution~markConverged(iteration, 0)
    return solution
  end

  raise syntax 93.900 array('transient nonlinear solve did not converge after ' || maxIterations || ' iterations at ' || timePs || ' ps')

::method gaussianSolve private
  numeric digits 50
  use strict arg matrix, rhs
  n = rhs~items
  a = .array~new(n)
  b = .array~new(n)

  do i = 1 to n
    a[i] = matrix[i]~copy
    b[i] = rhs[i]
  end

  do k = 1 to n
    pivot = k
    maxValue = abs(a[k][k])
    do row = k + 1 to n
      v = abs(a[row][k])
      if v > maxValue then do
        maxValue = v
        pivot = row
      end
    end

    if maxValue < 1e-30 then raise syntax 93.900 array('singular or floating transient network at equation ' || k)

    if pivot <> k then do
      tempRow = a[k]
      a[k] = a[pivot]
      a[pivot] = tempRow
      tempValue = b[k]
      b[k] = b[pivot]
      b[pivot] = tempValue
    end

    pivotValue = a[k][k]
    do col = k to n
      a[k][col] = a[k][col] / pivotValue
    end
    b[k] = b[k] / pivotValue

    do row = 1 to n
      if row <> k then do
        factor = a[row][k]
        if factor <> 0 then do
          do col = k to n
            a[row][col] = a[row][col] - factor * a[k][col]
          end
          b[row] = b[row] - factor * b[k]
        end
      end
    end
  end

  return b


::requires 'RexxTronicsTime.cls'
