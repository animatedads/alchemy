/* Rexx-tronics feedback regulator models v0.1-dev15.
 *
 * This is deliberately not an ideal voltage clamp.  The regulator exposes a
 * finite pass path from VIN to VOUT and an explicit three-pole control state.
 * External output capacitance is therefore part of the electrical plant and
 * can materially change the closed-loop response.
 *
 * Exact part definitions should provide these loop parameters from evidence.
 * The generic class does not claim that every regulator is unstable without
 * output capacitance.
 */

::class FeedbackLinearRegulator subclass ElectricalComponent public
::attribute targetVolts get
::attribute basePassConductanceSiemens get
::attribute passConductanceSiemens get
::attribute minimumPassConductanceSiemens get
::attribute maximumPassConductanceSiemens get
::attribute controlGainSiemensPerVolt get
::attribute pole1Seconds get
::attribute pole2Seconds get
::attribute pole3Seconds get
::attribute controlState1 get
::attribute controlState2 get
::attribute controlState3 get
::attribute lastOutputVolts get
::attribute lastInputCurrentAmps get
::attribute lastPowerWatts get

::method init
  expose targetVolts basePassConductanceSiemens passConductanceSiemens minimumPassConductanceSiemens maximumPassConductanceSiemens controlGainSiemensPerVolt pole1Seconds pole2Seconds pole3Seconds controlState1 controlState2 controlState3 lastOutputVolts lastInputCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg idArg, targetArg, basePassArg, controlGainArg, pole1Arg, pole2Arg, pole3Arg, minimumPassArg=0.000001, maximumPassArg=1
  self~init:super(idArg, 'FEEDBACK_LINEAR_REGULATOR')
  self~definePin(1, 'VIN', 'POWER_IN', 'POWER_IN')
  self~definePin(2, 'VOUT', 'POWER_OUT', 'POWER_OUT')
  self~definePin(3, 'GND', 'GROUND', 'GROUND')

  targetVolts = .RexxTronicsUnits~canonical(targetArg, .Units~volt, 'regulator target voltage')
  basePassConductanceSiemens = .RexxTronicsUnits~canonical(basePassArg, .Units~siemens, 'regulator base pass conductance')
  minimumPassConductanceSiemens = .RexxTronicsUnits~canonical(minimumPassArg, .Units~siemens, 'minimum regulator pass conductance')
  maximumPassConductanceSiemens = .RexxTronicsUnits~canonical(maximumPassArg, .Units~siemens, 'maximum regulator pass conductance')
  if basePassConductanceSiemens <= 0 then raise syntax 93.900 array('regulator base pass conductance must be positive')
  if minimumPassConductanceSiemens <= 0 then raise syntax 93.900 array('regulator minimum pass conductance must be positive')
  if maximumPassConductanceSiemens <= minimumPassConductanceSiemens then raise syntax 93.900 array('regulator maximum pass conductance must exceed minimum')
  if basePassConductanceSiemens < minimumPassConductanceSiemens | basePassConductanceSiemens > maximumPassConductanceSiemens then -
      raise syntax 93.900 array('regulator base pass conductance must lie inside pass limits')

  gainUnit = .Units~siemens / .Units~volt
  if controlGainArg~isA(.UnitQuantity) then controlGainSiemensPerVolt = controlGainArg~in(gainUnit)
  else controlGainSiemensPerVolt = controlGainArg + 0
  if controlGainSiemensPerVolt <= 0 then raise syntax 93.900 array('regulator control gain must be positive')

  pole1Seconds = .RexxTronicsUnits~canonical(pole1Arg, .Units~second, 'regulator control pole 1')
  pole2Seconds = .RexxTronicsUnits~canonical(pole2Arg, .Units~second, 'regulator control pole 2')
  pole3Seconds = .RexxTronicsUnits~canonical(pole3Arg, .Units~second, 'regulator control pole 3')
  if pole1Seconds <= 0 | pole2Seconds <= 0 | pole3Seconds <= 0 then -
      raise syntax 93.900 array('regulator control-pole time constants must be positive')

  passConductanceSiemens = basePassConductanceSiemens
  controlState1 = 0
  controlState2 = 0
  controlState3 = 0
  lastOutputVolts = 0
  lastInputCurrentAmps = 0
  lastPowerWatts = 0

::method input
  return self~pin('VIN')

::method output
  return self~pin('VOUT')

::method reference
  return self~pin('GND')

::method targetVoltage
  expose targetVolts
  return .Units~q(targetVolts, .Units~volt)

::method passConductance
  expose passConductanceSiemens
  return .Units~q(passConductanceSiemens, .Units~siemens)

::method passResistance
  expose passConductanceSiemens
  return .Units~q(1 / passConductanceSiemens, .Units~ohm)

::method outputVoltage
  expose lastOutputVolts
  return .Units~q(lastOutputVolts, .Units~volt)

::method inputCurrent
  expose lastInputCurrentAmps
  return .Units~q(lastInputCurrentAmps, .Units~ampere)

::method power
  expose lastPowerWatts
  return .Units~q(lastPowerWatts, .Units~watt)

::method electricalPathPeers
  use strict arg pin
  if pin == self~input then return .array~of(self~output)
  if pin == self~output then return .array~of(self~input)
  return .array~new

::method dcStamp
  expose passConductanceSiemens
  use strict arg context
  context~stampConductance(self~input, self~output, passConductanceSiemens)
  return .true

::method dcUpdate
  expose passConductanceSiemens lastOutputVolts lastInputCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution
  vin = solution~voltage(self~input~net)
  vout = solution~voltage(self~output~net)
  vgnd = solution~voltage(self~reference~net)
  lastOutputVolts = vout - vgnd
  lastInputCurrentAmps = passConductanceSiemens * (vin - vout)
  lastPowerWatts = (vin - vout) * lastInputCurrentAmps
  solution~setCurrent(self, lastInputCurrentAmps)
  solution~setPower(self, lastPowerWatts)
  return .true

::method transientInitialize
  expose passConductanceSiemens basePassConductanceSiemens controlState1 controlState2 controlState3
  use strict arg solution
  passConductanceSiemens = basePassConductanceSiemens
  controlState1 = 0
  controlState2 = 0
  controlState3 = 0
  return self~dcUpdate(solution)

::method transientStamp
  expose passConductanceSiemens
  use strict arg context, deltaSeconds, timePs
  context~stampConductance(self~input, self~output, passConductanceSiemens)
  return .true

::method transientUpdate
  expose targetVolts basePassConductanceSiemens passConductanceSiemens minimumPassConductanceSiemens maximumPassConductanceSiemens controlGainSiemensPerVolt pole1Seconds pole2Seconds pole3Seconds controlState1 controlState2 controlState3 lastOutputVolts lastInputCurrentAmps lastPowerWatts
  numeric digits 50
  use strict arg solution, deltaSeconds, timePs
  dt = deltaSeconds + 0
  if dt <= 0 then raise syntax 93.900 array('regulator transient time step must be positive')

  vin = solution~voltage(self~input~net)
  vout = solution~voltage(self~output~net)
  vgnd = solution~voltage(self~reference~net)
  lastOutputVolts = vout - vgnd
  lastInputCurrentAmps = passConductanceSiemens * (vin - vout)
  lastPowerWatts = (vin - vout) * lastInputCurrentAmps
  solution~setCurrent(self, lastInputCurrentAmps)
  solution~setPower(self, lastPowerWatts)

  errorVolts = targetVolts - lastOutputVolts
  targetCorrection = controlGainSiemensPerVolt * errorVolts
  /* Three explicit physical state poles.  Backward-Euler coefficients keep
   * each individual pole numerically stable; any resulting loop oscillation
   * therefore comes from the closed-loop model, not from an unstable pole
   * integrator.  State changes become causal input to the next electrical
   * timestep and are committed only after this electrical solve converges. */
  a1 = dt / (pole1Seconds + dt)
  a2 = dt / (pole2Seconds + dt)
  a3 = dt / (pole3Seconds + dt)
  controlState1 = controlState1 + a1 * (targetCorrection - controlState1)
  controlState2 = controlState2 + a2 * (controlState1 - controlState2)
  controlState3 = controlState3 + a3 * (controlState2 - controlState3)

  passConductanceSiemens = basePassConductanceSiemens + controlState3
  if passConductanceSiemens < minimumPassConductanceSiemens then passConductanceSiemens = minimumPassConductanceSiemens
  if passConductanceSiemens > maximumPassConductanceSiemens then passConductanceSiemens = maximumPassConductanceSiemens
  return .true


::requires 'RexxTronicsDC.cls'
