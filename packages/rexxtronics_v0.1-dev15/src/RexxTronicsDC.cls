/* Rexx-tronics linear/DC-capable components v0.1-dev15 */

::class ElectricalComponent public
::attribute id get
::attribute kind get
::attribute circuit get

::method init
  expose id kind circuit pinMap pinOrder
  use strict arg idArg, kindArg='COMPONENT'
  id = idArg~string
  kind = kindArg~string~upper
  circuit = .nil
  pinMap = .directory~new
  pinOrder = .array~new

::method definePin
  expose pinMap pinOrder
  use strict arg number, name, role='SIGNAL', electricalType='PASSIVE'
  key = name~string~upper
  if pinMap~hasIndex(key) then raise syntax 93.900 array('duplicate component pin ' || self~id || '.' || name)
  p = .Pin~new(number, name, role, electricalType, self)
  pinMap[key] = p
  pinOrder~append(p)
  return p

::method pin
  expose pinMap
  use strict arg name
  key = name~string~upper
  if \pinMap~hasIndex(key) then raise syntax 93.900 array('unknown component pin ' || self~id || '.' || name)
  return pinMap[key]

::method pins
  expose pinOrder
  return pinOrder~copy

::method attachCircuit
  expose circuit
  use strict arg circuitArg
  if circuit <> .nil & circuit <> circuitArg then raise syntax 93.900 array('component already belongs to another circuit')
  circuit = circuitArg
  return self

::method electricalPathPeers
  use strict arg pin
  return .array~new

::method dcExtraEquations
  return 0

::method dcStamp
  use strict arg context
  return .true

::method dcUpdate
  use strict arg solution
  return .true

/* Nonlinear devices can update their linearized operating region after a solve.
 * Return .true only when the matrix must be rebuilt and solved again.
 */
::method dcNeedsResolve
  use strict arg solution
  return .false

/* Default transient behaviour for memoryless linear components is their DC law. */
::method transientExtraEquations
  return self~dcExtraEquations

::method transientInitialize
  use strict arg solution
  return .true

::method transientStamp
  use strict arg context, deltaSeconds, timePs
  return self~dcStamp(context)

::method transientNeedsResolve
  use strict arg solution, deltaSeconds, timePs
  return self~dcNeedsResolve(solution)

::method transientUpdate
  use strict arg solution, deltaSeconds, timePs
  return self~dcUpdate(solution)

::method string
  expose id kind
  return id || ' (' || kind || ')'


::class TwoTerminalComponent subclass ElectricalComponent public
::method init
  use strict arg idArg, kindArg='TWO_TERMINAL', pinAName='A', pinBName='B'
  self~init:super(idArg, kindArg)
  self~definePin(1, pinAName, 'TERMINAL', 'PASSIVE')
  self~definePin(2, pinBName, 'TERMINAL', 'PASSIVE')

::method terminalA
  return self~pins[1]

::method terminalB
  return self~pins[2]

::method electricalPathPeers
  use strict arg pin
  a = self~pins[1]
  b = self~pins[2]
  if pin == a then return .array~of(b)
  if pin == b then return .array~of(a)
  return .array~new


::class Resistor subclass TwoTerminalComponent public
::attribute resistanceOhms get
::attribute tolerancePercent get
::attribute powerRatingWatts get
::attribute lastCurrentAmps get
::attribute lastPowerWatts get

::method init
  expose resistanceOhms tolerancePercent powerRatingWatts lastCurrentAmps lastPowerWatts
  use strict arg idArg, resistanceArg, toleranceArg=5, powerRatingArg=0.25, kindArg='RESISTOR'
  self~init:super(idArg, kindArg, 'A', 'B')
  resistanceOhms = .RexxTronicsUnits~canonical(resistanceArg, .Units~ohm, 'resistance')
  if resistanceOhms <= 0 then raise syntax 93.900 array('resistance must be positive')
  tolerancePercent = .RexxTronicsUnits~percent(toleranceArg, 'resistor tolerance')
  powerRatingWatts = .RexxTronicsUnits~canonical(powerRatingArg, .Units~watt, 'resistor power rating')
  lastCurrentAmps = 0
  lastPowerWatts = 0

::method setResistanceOhms
  expose resistanceOhms
  use strict arg newResistance
  value = .RexxTronicsUnits~canonical(newResistance, .Units~ohm, 'resistance')
  if value <= 0 then raise syntax 93.900 array('resistance must be positive')
  resistanceOhms = value
  return resistanceOhms

::method resistance
  expose resistanceOhms
  return .Units~q(resistanceOhms, .Units~ohm)

::method tolerance
  expose tolerancePercent
  return .Units~q(tolerancePercent, .Units~percent)

::method powerRating
  expose powerRatingWatts
  return .Units~q(powerRatingWatts, .Units~watt)

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method dcStamp
  expose resistanceOhms
  use strict arg context
  context~stampConductance(self~pin('A'), self~pin('B'), 1 / resistanceOhms)
  return .true

::method dcUpdate
  expose resistanceOhms lastCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution
  va = solution~voltage(self~pin('A')~net)
  vb = solution~voltage(self~pin('B')~net)
  lastCurrentAmps = (va - vb) / resistanceOhms
  lastPowerWatts = lastCurrentAmps * lastCurrentAmps * resistanceOhms
  solution~setCurrent(self, lastCurrentAmps)
  solution~setPower(self, lastPowerWatts)
  return .true


::class VariableResistor subclass Resistor public
::attribute minimumOhms get
::attribute maximumOhms get
::attribute position get

::method init
  expose minimumOhms maximumOhms position
  use strict arg idArg, minimumArg, maximumArg, positionArg=0.5, toleranceArg=5, powerRatingArg=0.25
  minimumOhms = .RexxTronicsUnits~canonical(minimumArg, .Units~ohm, 'minimum resistance')
  maximumOhms = .RexxTronicsUnits~canonical(maximumArg, .Units~ohm, 'maximum resistance')
  if minimumOhms <= 0 | maximumOhms < minimumOhms then raise syntax 93.900 array('invalid variable-resistor range')
  position = .RexxTronicsUnits~ratio(positionArg, 'variable-resistor position')
  if position < 0 | position > 1 then raise syntax 93.900 array('variable-resistor position must be 0..1')
  initialResistance = minimumOhms + position * (maximumOhms - minimumOhms)
  self~init:super(idArg, initialResistance, toleranceArg, powerRatingArg)

::method setPosition
  expose minimumOhms maximumOhms position
  use strict arg newPosition
  p = .RexxTronicsUnits~ratio(newPosition, 'variable-resistor position')
  if p < 0 | p > 1 then raise syntax 93.900 array('variable-resistor position must be 0..1')
  position = p
  return self~setResistanceOhms(minimumOhms + p * (maximumOhms - minimumOhms))

::method setResistance
  expose minimumOhms maximumOhms position
  use strict arg ohms
  value = .RexxTronicsUnits~canonical(ohms, .Units~ohm, 'variable-resistor resistance')
  if value < minimumOhms | value > maximumOhms then raise syntax 93.900 array('variable-resistor value outside configured range')
  if maximumOhms = minimumOhms then position = 0
  else position = (value - minimumOhms) / (maximumOhms - minimumOhms)
  return self~setResistanceOhms(value)


::class Potentiometer subclass ElectricalComponent public
::attribute totalResistanceOhms get
::attribute position get
::attribute lastAWCurrentAmps get
::attribute lastWBCurrentAmps get

::method init
  expose totalResistanceOhms position lastAWCurrentAmps lastWBCurrentAmps minimumSegmentOhms
  use strict arg idArg, totalResistanceArg, positionArg=0.5
  self~init:super(idArg, 'POTENTIOMETER')
  totalResistanceOhms = .RexxTronicsUnits~canonical(totalResistanceArg, .Units~ohm, 'potentiometer resistance')
  if totalResistanceOhms <= 0 then raise syntax 93.900 array('potentiometer resistance must be positive')
  position = .RexxTronicsUnits~ratio(positionArg, 'potentiometer position')
  if position < 0 | position > 1 then raise syntax 93.900 array('potentiometer position must be 0..1')
  minimumSegmentOhms = 0.000001
  lastAWCurrentAmps = 0
  lastWBCurrentAmps = 0
  self~definePin(1, 'A', 'TERMINAL', 'PASSIVE')
  self~definePin(2, 'W', 'WIPER', 'PASSIVE')
  self~definePin(3, 'B', 'TERMINAL', 'PASSIVE')

::method totalResistance
  expose totalResistanceOhms
  return .Units~q(totalResistanceOhms, .Units~ohm)

::method currentAW
  expose lastAWCurrentAmps
  return .Units~q(lastAWCurrentAmps, .Units~ampere)

::method currentWB
  expose lastWBCurrentAmps
  return .Units~q(lastWBCurrentAmps, .Units~ampere)

::method setPosition
  expose position
  use strict arg newPosition
  p = .RexxTronicsUnits~ratio(newPosition, 'potentiometer position')
  if p < 0 | p > 1 then raise syntax 93.900 array('potentiometer position must be 0..1')
  position = p
  return position

/* position 0 means wiper at B, position 1 means wiper at A. */
::method resistanceAW private
  expose totalResistanceOhms position minimumSegmentOhms
  r = (1 - position) * totalResistanceOhms
  if r < minimumSegmentOhms then r = minimumSegmentOhms
  return r

::method resistanceWB private
  expose totalResistanceOhms position minimumSegmentOhms
  r = position * totalResistanceOhms
  if r < minimumSegmentOhms then r = minimumSegmentOhms
  return r

::method electricalPathPeers
  use strict arg pin
  peers = .array~new
  do p over self~pins
    if p <> pin then peers~append(p)
  end
  return peers

::method dcStamp
  use strict arg context
  context~stampConductance(self~pin('A'), self~pin('W'), 1 / self~resistanceAW)
  context~stampConductance(self~pin('W'), self~pin('B'), 1 / self~resistanceWB)
  return .true

::method dcUpdate
  expose lastAWCurrentAmps lastWBCurrentAmps
  use strict arg solution
  va = solution~voltage(self~pin('A')~net)
  vw = solution~voltage(self~pin('W')~net)
  vb = solution~voltage(self~pin('B')~net)
  lastAWCurrentAmps = (va - vw) / self~resistanceAW
  lastWBCurrentAmps = (vw - vb) / self~resistanceWB
  solution~setPower(self, (va-vw)*lastAWCurrentAmps + (vw-vb)*lastWBCurrentAmps)
  return .true


::class Switch subclass TwoTerminalComponent public
::attribute closed get
::attribute closedResistanceOhms get
::attribute openResistanceOhms get
::attribute lastCurrentAmps get

::method init
  expose closed closedResistanceOhms openResistanceOhms lastCurrentAmps
  use strict arg idArg, closedArg=.false, closedResistanceArg=0.001, openResistanceArg=1e12
  self~init:super(idArg, 'SWITCH', 'A', 'B')
  closed = closedArg
  closedResistanceOhms = .RexxTronicsUnits~canonical(closedResistanceArg, .Units~ohm, 'closed switch resistance')
  openResistanceOhms = .RexxTronicsUnits~canonical(openResistanceArg, .Units~ohm, 'open switch resistance')
  if closedResistanceOhms <= 0 | openResistanceOhms <= closedResistanceOhms then raise syntax 93.900 array('invalid switch resistance model')
  lastCurrentAmps = 0

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method close
  expose closed
  closed = .true
  return self

::method open
  expose closed
  closed = .false
  return self

::method setClosed
  expose closed
  use strict arg state
  closed = state
  return self

::method effectiveResistance private
  expose closed closedResistanceOhms openResistanceOhms
  if closed then return closedResistanceOhms
  return openResistanceOhms

::method electricalPathPeers
  expose closed
  use strict arg pin
  if \closed then return .array~new
  return self~electricalPathPeers:super(pin)

::method dcStamp
  use strict arg context
  context~stampConductance(self~pin('A'), self~pin('B'), 1 / self~effectiveResistance)
  return .true

::method dcUpdate
  expose lastCurrentAmps
  use strict arg solution
  va = solution~voltage(self~pin('A')~net)
  vb = solution~voltage(self~pin('B')~net)
  lastCurrentAmps = (va - vb) / self~effectiveResistance
  solution~setCurrent(self, lastCurrentAmps)
  solution~setPower(self, (va-vb) * lastCurrentAmps)
  return .true


::class Capacitor subclass TwoTerminalComponent public
::attribute capacitanceFarads get
::attribute initialVoltage get
::attribute previousVoltage get
::attribute lastCurrentAmps get
::attribute lastPowerWatts get

::method init
  expose capacitanceFarads initialVoltage previousVoltage lastCurrentAmps lastPowerWatts
  use strict arg idArg, capacitanceArg, initialVoltageArg=0
  self~init:super(idArg, 'CAPACITOR', 'A', 'B')
  capacitanceFarads = .RexxTronicsUnits~canonical(capacitanceArg, .Units~farad, 'capacitance')
  if capacitanceFarads <= 0 then raise syntax 93.900 array('capacitance must be positive')
  initialVoltage = .RexxTronicsUnits~canonical(initialVoltageArg, .Units~volt, 'capacitor initial voltage')
  previousVoltage = initialVoltage
  lastCurrentAmps = 0
  lastPowerWatts = 0

::method capacitance
  expose capacitanceFarads
  return .Units~q(capacitanceFarads, .Units~farad)

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method storedVoltage
  expose previousVoltage
  return .Units~q(previousVoltage, .Units~volt)

/* A capacitor is open circuit in the DC operating-point model. */
::method dcStamp
  use strict arg context
  return .true

::method dcUpdate
  expose lastCurrentAmps lastPowerWatts
  use strict arg solution
  lastCurrentAmps = 0
  lastPowerWatts = 0
  solution~setCurrent(self, 0)
  solution~setPower(self, 0)
  return .true

::method transientInitialize
  expose initialVoltage previousVoltage
  use strict arg solution
  /* Explicit initialVoltage is authoritative for stored capacitor state. */
  previousVoltage = initialVoltage
  return .true

::method transientStamp
  expose capacitanceFarads previousVoltage
  numeric digits 50
  use strict arg context, deltaSeconds, timePs
  dt = deltaSeconds + 0
  if dt <= 0 then raise syntax 93.900 array('transient time step must be positive')
  g = capacitanceFarads / dt
  context~stampConductance(self~pin('A'), self~pin('B'), g)
  /* Backward-Euler companion source: i = G*Vnew - G*Vprevious. */
  context~stampCurrent(self~pin('A'), self~pin('B'), -g * previousVoltage)
  return .true

::method transientUpdate
  expose capacitanceFarads previousVoltage lastCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution, deltaSeconds, timePs
  va = solution~voltage(self~pin('A')~net)
  vb = solution~voltage(self~pin('B')~net)
  vnew = va - vb
  lastCurrentAmps = capacitanceFarads * (vnew - previousVoltage) / deltaSeconds
  lastPowerWatts = vnew * lastCurrentAmps
  previousVoltage = vnew
  solution~setCurrent(self, lastCurrentAmps)
  solution~setPower(self, lastPowerWatts)
  return .true


::class Inductor subclass TwoTerminalComponent public
::attribute inductanceHenrys get
::attribute initialCurrentAmps get
::attribute previousCurrentAmps get
::attribute lastCurrentAmps get
::attribute lastPowerWatts get

::method init
  expose inductanceHenrys initialCurrentAmps previousCurrentAmps lastCurrentAmps lastPowerWatts
  use strict arg idArg, inductanceArg, initialCurrentArg=0
  self~init:super(idArg, 'INDUCTOR', 'A', 'B')
  inductanceHenrys = .RexxTronicsUnits~canonical(inductanceArg, .Units~henry, 'inductance')
  if inductanceHenrys <= 0 then raise syntax 93.900 array('inductance must be positive')
  initialCurrentAmps = .RexxTronicsUnits~canonical(initialCurrentArg, .Units~ampere, 'inductor initial current')
  previousCurrentAmps = initialCurrentAmps
  lastCurrentAmps = initialCurrentAmps
  lastPowerWatts = 0

::method inductance
  expose inductanceHenrys
  return .Units~q(inductanceHenrys, .Units~henry)

::method storedCurrent
  expose previousCurrentAmps
  return .Units~q(previousCurrentAmps, .Units~ampere)

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method storedEnergy
  expose inductanceHenrys previousCurrentAmps
  numeric digits 50
  return .Units~q(0.5 * inductanceHenrys * previousCurrentAmps * previousCurrentAmps, .Units~joule)

/* An ideal inductor is a short circuit at DC steady state.  MNA allocates a
 * zero-volt source equation so the branch current remains observable.
 */
::method dcExtraEquations
  return 1

::method dcStamp
  use strict arg context
  context~stampVoltageSource(self, self~pin('A'), self~pin('B'), 0)
  return .true

::method dcUpdate
  expose lastCurrentAmps lastPowerWatts
  use strict arg solution
  i = solution~current(self)
  if i == .nil then i = 0
  lastCurrentAmps = i
  lastPowerWatts = 0
  solution~setCurrent(self, i)
  solution~setPower(self, 0)
  return .true

/* Backward-Euler companion model requires no extra MNA branch equation:
 *   i[n] = i[n-1] + (dt/L) * v[n]
 * so the inductor is represented as conductance dt/L in parallel with a
 * history current source i[n-1].
 */
::method transientExtraEquations
  return 0

::method transientInitialize
  expose initialCurrentAmps previousCurrentAmps lastCurrentAmps lastPowerWatts
  use strict arg solution
  previousCurrentAmps = initialCurrentAmps
  lastCurrentAmps = initialCurrentAmps
  lastPowerWatts = 0
  return .true

::method transientStamp
  expose inductanceHenrys previousCurrentAmps
  numeric digits 50
  use strict arg context, deltaSeconds, timePs
  dt = deltaSeconds + 0
  if dt <= 0 then raise syntax 93.900 array('transient time step must be positive')
  g = dt / inductanceHenrys
  context~stampConductance(self~pin('A'), self~pin('B'), g)
  context~stampCurrent(self~pin('A'), self~pin('B'), previousCurrentAmps)
  return .true

::method transientUpdate
  expose inductanceHenrys previousCurrentAmps lastCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution, deltaSeconds, timePs
  va = solution~voltage(self~pin('A')~net)
  vb = solution~voltage(self~pin('B')~net)
  vnew = va - vb
  inew = previousCurrentAmps + (deltaSeconds / inductanceHenrys) * vnew
  lastCurrentAmps = inew
  lastPowerWatts = vnew * inew
  previousCurrentAmps = inew
  solution~setCurrent(self, inew)
  solution~setPower(self, lastPowerWatts)
  return .true


::class DCVoltageSource subclass TwoTerminalComponent public
::attribute volts get

::method init
  expose volts
  use strict arg idArg, voltsArg
  self~init:super(idArg, 'DC_VOLTAGE_SOURCE', 'POS', 'NEG')
  volts = .RexxTronicsUnits~canonical(voltsArg, .Units~volt, 'source voltage')

::method voltage
  expose volts
  return .Units~q(volts, .Units~volt)

::method positive
  return self~pin('POS')

::method negative
  return self~pin('NEG')

::method dcExtraEquations
  return 1

::method dcStamp
  expose volts
  use strict arg context
  context~stampVoltageSource(self, self~positive, self~negative, volts)
  return .true

::method dcUpdate
  use strict arg solution
  i = solution~current(self)
  if i == .nil then return .true
  vp = solution~voltage(self~positive~net)
  vn = solution~voltage(self~negative~net)
  solution~setPower(self, (vp - vn) * i)
  return .true


::class StepVoltageSource subclass DCVoltageSource public
::attribute initialVolts get
::attribute finalVolts get
::attribute stepTimePs get

::method init
  expose initialVolts finalVolts stepTimePs volts
  use strict arg idArg, initialArg, finalArg, stepTimeArg
  initialVolts = .RexxTronicsUnits~canonical(initialArg, .Units~volt, 'initial source voltage')
  finalVolts = .RexxTronicsUnits~canonical(finalArg, .Units~volt, 'final source voltage')
  stepTimePs = .RexxTronicsUnits~timePicoseconds(stepTimeArg)
  volts = initialVolts
  self~init:super(idArg, initialVolts)

::method voltsAt
  expose initialVolts finalVolts stepTimePs
  use strict arg time
  t = .RexxTronicsUnits~timePicoseconds(time)
  if t < stepTimePs then return initialVolts
  return finalVolts

::method transientStamp
  use strict arg context, deltaSeconds, timePs
  context~stampVoltageSource(self, self~positive, self~negative, self~voltsAt(timePs))
  return .true



::class SineVoltageSource subclass DCVoltageSource public
::attribute offsetVolts get
::attribute amplitudeVolts get
::attribute frequencyHz get
::attribute phaseRadians get

::method init
  expose offsetVolts amplitudeVolts frequencyHz phaseRadians
  numeric digits 50
  use strict arg idArg, offsetArg, amplitudeArg, frequencyArg, phaseArg=0
  offsetVolts = .RexxTronicsUnits~canonical(offsetArg, .Units~volt, 'sine source DC offset')
  amplitudeVolts = .RexxTronicsUnits~canonical(amplitudeArg, .Units~volt, 'sine source amplitude')
  frequencyHz = .RexxTronicsUnits~canonical(frequencyArg, .Units~hertz, 'sine source frequency')
  phaseRadians = .RexxTronicsUnits~ratio(phaseArg, 'sine source phase')
  if amplitudeVolts < 0 then raise syntax 93.900 array('sine source amplitude must not be negative')
  if frequencyHz <= 0 then raise syntax 93.900 array('sine source frequency must be positive')
  self~init:super(idArg, offsetVolts)

::method voltsAt
  expose offsetVolts amplitudeVolts frequencyHz phaseRadians
  numeric digits 50
  use strict arg time
  timePs = .RexxTronicsUnits~timePicoseconds(time)
  t = timePs / .SimTime~PS_PER_S
  pi = 4 * RxCalcArcTan(1, 40, 'R')
  return offsetVolts + amplitudeVolts * RxCalcSin(2*pi*frequencyHz*t + phaseRadians, 40, 'R')

::method transientStamp
  use strict arg context, deltaSeconds, timePs
  context~stampVoltageSource(self, self~positive, self~negative, self~voltsAt(timePs))
  return .true

::class DCCurrentSource subclass TwoTerminalComponent public
::attribute amps get

::method init
  expose amps
  use strict arg idArg, ampsArg
  self~init:super(idArg, 'DC_CURRENT_SOURCE', 'FROM', 'TO')
  amps = .RexxTronicsUnits~canonical(ampsArg, .Units~ampere, 'source current')

::method current
  expose amps
  return .Units~q(amps, .Units~ampere)

::method fromPin
  return self~pin('FROM')

::method toPin
  return self~pin('TO')

::method dcStamp
  expose amps
  use strict arg context
  context~stampCurrent(self~fromPin, self~toPin, amps)
  return .true

::method dcUpdate
  expose amps
  use strict arg solution
  solution~setCurrent(self, amps)
  vf = solution~voltage(self~fromPin~net)
  vt = solution~voltage(self~toPin~net)
  solution~setPower(self, (vf - vt) * amps)
  return .true


/* Piecewise-linear diode suitable for deterministic circuit solving without
 * burying a semiconductor SPICE engine inside the component object.  Exact
 * part definitions can replace these parameters from datasheet ingestion.
 *
 * FORWARD: i(A->K) = (VAK - Vf) / Ron
 * OFF:     i(A->K) = VAK / Roff
 * REVERSE: i(A->K) = (VAK + Vbr) / Rrev, when breakdown is configured
 */
::class Diode subclass TwoTerminalComponent public
::attribute forwardVoltageVolts get
::attribute onResistanceOhms get
::attribute offResistanceOhms get
::attribute reverseBreakdownVolts get
::attribute reverseResistanceOhms get
::attribute state get
::attribute lastCurrentAmps get
::attribute lastPowerWatts get

::method init
  expose forwardVoltageVolts onResistanceOhms offResistanceOhms reverseBreakdownVolts reverseResistanceOhms state hysteresisVolts lastCurrentAmps lastPowerWatts
  use strict arg idArg, forwardVoltageArg='0.7 V', onResistanceArg='1 Ohm', offResistanceArg=1000000000000, reverseBreakdownArg=.nil, reverseResistanceArg='5 Ohm', hysteresisArg='1 mV'
  self~init:super(idArg, 'DIODE', 'ANODE', 'CATHODE')
  forwardVoltageVolts = .RexxTronicsUnits~canonical(forwardVoltageArg, .Units~volt, 'diode forward voltage')
  onResistanceOhms = .RexxTronicsUnits~canonical(onResistanceArg, .Units~ohm, 'diode on resistance')
  offResistanceOhms = .RexxTronicsUnits~canonical(offResistanceArg, .Units~ohm, 'diode off resistance')
  reverseResistanceOhms = .RexxTronicsUnits~canonical(reverseResistanceArg, .Units~ohm, 'diode reverse resistance')
  hysteresisVolts = .RexxTronicsUnits~canonical(hysteresisArg, .Units~volt, 'diode switching hysteresis')
  if forwardVoltageVolts < 0 then raise syntax 93.900 array('diode forward voltage must not be negative')
  if onResistanceOhms <= 0 | offResistanceOhms <= 0 | reverseResistanceOhms <= 0 then raise syntax 93.900 array('diode resistances must be positive')
  if reverseBreakdownArg == .nil then reverseBreakdownVolts = .nil
  else do
    reverseBreakdownVolts = .RexxTronicsUnits~canonical(reverseBreakdownArg, .Units~volt, 'diode reverse breakdown voltage')
    if reverseBreakdownVolts <= 0 then raise syntax 93.900 array('diode reverse breakdown magnitude must be positive')
  end
  state = 'OFF'
  lastCurrentAmps = 0
  lastPowerWatts = 0

::method anode
  return self~pin('ANODE')

::method cathode
  return self~pin('CATHODE')

::method forwardVoltage
  expose forwardVoltageVolts
  return .Units~q(forwardVoltageVolts, .Units~volt)

::method current
  expose lastCurrentAmps
  return .Units~q(lastCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method voltageDrop
  if self~anode~net == .nil | self~cathode~net == .nil then return .nil
  va = self~anode~voltage
  vk = self~cathode~voltage
  if va == .nil | vk == .nil then return .nil
  return .Units~q(va - vk, .Units~volt)

::method desiredState private
  expose state forwardVoltageVolts reverseBreakdownVolts hysteresisVolts
  use strict arg volts
  v = volts + 0
  /* Small hysteresis prevents operating-point chatter exactly at a knee. */
  if state = 'FORWARD' then do
    if v >= forwardVoltageVolts - hysteresisVolts then return 'FORWARD'
  end
  if state = 'REVERSE' & reverseBreakdownVolts <> .nil then do
    if v <= -reverseBreakdownVolts + hysteresisVolts then return 'REVERSE'
  end
  if v >= forwardVoltageVolts then return 'FORWARD'
  if reverseBreakdownVolts <> .nil then do
    if v <= -reverseBreakdownVolts then return 'REVERSE'
  end
  return 'OFF'

::method currentForVoltage private
  expose state forwardVoltageVolts onResistanceOhms offResistanceOhms reverseBreakdownVolts reverseResistanceOhms
  use strict arg volts
  v = volts + 0
  select
    when state = 'FORWARD' then return (v - forwardVoltageVolts) / onResistanceOhms
    when state = 'REVERSE' then return (v + reverseBreakdownVolts) / reverseResistanceOhms
    otherwise return v / offResistanceOhms
  end

::method dcStamp
  expose state forwardVoltageVolts onResistanceOhms offResistanceOhms reverseBreakdownVolts reverseResistanceOhms
  use strict arg context
  select
    when state = 'FORWARD' then do
      g = 1 / onResistanceOhms
      context~stampConductance(self~anode, self~cathode, g)
      /* -g*Vf offset current is represented as K -> A. */
      context~stampCurrent(self~cathode, self~anode, g * forwardVoltageVolts)
    end
    when state = 'REVERSE' then do
      g = 1 / reverseResistanceOhms
      context~stampConductance(self~anode, self~cathode, g)
      /* +g*Vbr offset current is represented as A -> K. */
      context~stampCurrent(self~anode, self~cathode, g * reverseBreakdownVolts)
    end
    otherwise context~stampConductance(self~anode, self~cathode, 1 / offResistanceOhms)
  end
  return .true

::method dcNeedsResolve
  expose state
  use strict arg solution
  va = solution~voltage(self~anode~net)
  vk = solution~voltage(self~cathode~net)
  desired = self~desiredState(va - vk)
  if desired = state then return .false
  state = desired
  return .true

::method dcUpdate
  expose lastCurrentAmps lastPowerWatts
  use strict arg solution
  va = solution~voltage(self~anode~net)
  vk = solution~voltage(self~cathode~net)
  vd = va - vk
  lastCurrentAmps = self~currentForVoltage(vd)
  lastPowerWatts = vd * lastCurrentAmps
  solution~setCurrent(self, lastCurrentAmps)
  solution~setPower(self, lastPowerWatts)
  return .true


::class ZenerDiode subclass Diode public
::method init
  use strict arg idArg, breakdownArg, forwardVoltageArg='0.7 V', onResistanceArg='1 Ohm', reverseResistanceArg='5 Ohm', offResistanceArg=1000000000000
  self~init:super(idArg, forwardVoltageArg, onResistanceArg, offResistanceArg, breakdownArg, reverseResistanceArg)


::class LED subclass Diode public
::attribute lightThresholdAmps get
::attribute radiantEfficiency get
::attribute wavelengthMeters get

::method init
  expose lightThresholdAmps radiantEfficiency wavelengthMeters
  use strict arg idArg, forwardVoltageArg='1.7 V', onResistanceArg='10 Ohm', lightThresholdArg='0.5 mA', radiantEfficiencyArg=.nil, wavelengthArg=.nil
  self~init:super(idArg, forwardVoltageArg, onResistanceArg, 1000000000000)
  lightThresholdAmps = .RexxTronicsUnits~canonical(lightThresholdArg, .Units~ampere, 'LED light threshold')
  if lightThresholdAmps < 0 then raise syntax 93.900 array('LED light threshold must not be negative')
  if radiantEfficiencyArg == .nil then radiantEfficiency = .nil
  else do
    radiantEfficiency = .RexxTronicsUnits~ratio(radiantEfficiencyArg, 'LED radiant efficiency')
    if radiantEfficiency < 0 | radiantEfficiency > 1 then raise syntax 93.900 array('LED radiant efficiency must be 0..1')
  end
  if wavelengthArg == .nil then wavelengthMeters = .nil
  else wavelengthMeters = .RexxTronicsUnits~canonical(wavelengthArg, .Units~metre, 'LED wavelength')

::method lit
  expose lightThresholdAmps
  return self~current~in(.Units~ampere) >= lightThresholdAmps

::method opticalPower
  expose radiantEfficiency
  if radiantEfficiency == .nil then return .nil
  watts = self~power~in(.Units~watt)
  if watts < 0 then watts = 0
  return .Units~q(watts * radiantEfficiency, .Units~watt)

::method wavelength
  expose wavelengthMeters
  if wavelengthMeters == .nil then return .nil
  return .Units~q(wavelengthMeters, .Units~metre)


::requires 'RexxTronicsElectrical.cls'
::requires 'rxmath' LIBRARY
