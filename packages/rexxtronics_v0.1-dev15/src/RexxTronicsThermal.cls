/* Rexx-tronics <-> ooRexx Physics thermal bridge v0.1-dev15.
 *
 * Electrical power is not silently assumed to be heat.  A caller creates an
 * explicit bridge from a solved electrical component to a Physics ThermalNode.
 * The bridge emits Physics' typed ThermalPowerObservation with source/cause/
 * solution evidence and an explicit 0..1 transfer fraction.
 */

::class ElectricalThermalPowerBridge public
::attribute component get
::attribute thermalNode get
::attribute fraction get
::attribute lastObservation get

::method init
  expose component thermalNode fraction lastObservation
  use strict arg componentArg, thermalNodeArg, fractionArg=1
  if \componentArg~hasMethod('ID') then raise syntax 93.900 array('thermal bridge requires an electrical component')
  if \thermalNodeArg~isA(.ThermalNode) then raise syntax 93.900 array('thermal bridge requires a Physics ThermalNode')
  component = componentArg
  thermalNode = thermalNodeArg
  fraction = .RexxTronicsUnits~ratio(fractionArg, 'electrical-to-thermal power fraction')
  if fraction < 0 | fraction > 1 then raise syntax 93.900 array('electrical-to-thermal power fraction must be 0..1')
  lastObservation = .nil

::method observeFromSolution
  expose component thermalNode fraction lastObservation
  numeric digits 50
  use strict arg solution, timeArg, causeArg='explicit electrical power -> Physics thermal transfer'
  watts = solution~power(component)
  if watts == .nil then raise syntax 93.900 array('electrical solution has no power observation for component ' || component~id)
  time = .RexxTronicsUnits~typed(timeArg, .Units~second, 'thermal bridge observation time')
  lastObservation = .ThermalPowerObservation~new(time, .Units~q(watts*fraction, .Units~watt), causeArg, component, solution)
  thermalNode~acceptPower(lastObservation)
  return lastObservation

::requires 'RexxTronicsDC.cls'
::requires 'Thermal.cls'
