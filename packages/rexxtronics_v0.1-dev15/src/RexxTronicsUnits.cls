/* Rexx-tronics shared Units boundary v0.1-dev15.
 *
 * ooRexx Units is authoritative for unit identity, dimensional compatibility,
 * conversion and canonical SI values.  Rexx-tronics accepts legacy naked
 * numerics for source compatibility, but all UnitQuantity inputs are validated
 * here before solver-normalized numeric values enter the electrical kernel.
 */

::class RexxTronicsUnits public

::method canonical class
  numeric digits 50
  use strict arg value, expectedUnit, label='quantity'
  if value~isA(.UnitQuantity) then return value~in(expectedUnit)

  /* Preserve the historical naked-numeric path first.  If it is not numeric,
   * dev2 Units may parse a typed textual quantity such as "4.7 kΩ" or
   * "250 mV".  Unit compatibility remains authoritative in Units.
   */
  signal on syntax name tryTextQuantity
  n = value + 0
  signal off syntax
  return n

tryTextQuantity:
  signal off syntax
  signal on syntax name badValue
  q = .Units~parseQuantity(value~string)
  n = q~in(expectedUnit)
  signal off syntax
  return n

badValue:
  signal off syntax
  raise syntax 93.900 array(label || ' must be numeric, a UnitQuantity, or a parseable quantity compatible with ' || expectedUnit~symbol)

::method quantity class
  use strict arg canonicalValue, unit, displayUnit=.nil
  if displayUnit == .nil then return .Units~q(canonicalValue, unit)
  return .Units~q(canonicalValue, unit, displayUnit)

::method timePicoseconds class
  numeric digits 50
  use strict arg value, numericUnit=.nil
  if value~hasMethod('PICOSECONDS') then return value~picoseconds
  if value~isA(.UnitQuantity) then do
    seconds = value~in(.Units~second)
    ps = seconds * 1000000000000
    if ps \= ps~trunc then raise syntax 93.900 array('simulation time must resolve to whole picoseconds')
    return ps
  end

  signal on syntax name tryTextTime
  n = value + 0
  signal off syntax
  if numericUnit == .nil then ps = n
  else ps = .Units~convert(n, numericUnit, .Units~second) * 1000000000000
  if ps \= ps~trunc then raise syntax 93.900 array('simulation time must resolve to whole picoseconds')
  return ps

tryTextTime:
  signal off syntax
  signal on syntax name badTime
  q = .Units~parseQuantity(value~string)
  seconds = q~in(.Units~second)
  ps = seconds * 1000000000000
  signal off syntax
  if ps \= ps~trunc then raise syntax 93.900 array('simulation time must resolve to whole picoseconds')
  return ps

badTime:
  signal off syntax
  raise syntax 93.900 array('simulation time must be picoseconds, SimInstant, or a time UnitQuantity/text quantity')

::method ratio class
  numeric digits 50
  use strict arg value, label='ratio'
  if value~isA(.UnitQuantity) then do
    if \value~dimension~isDimensionless then raise syntax 93.900 array(label || ' must be dimensionless')
    return value~canonicalValue
  end
  return value + 0

::method percent class
  numeric digits 50
  use strict arg value, label='percentage'
  if value~isA(.UnitQuantity) then do
    if \value~dimension~isDimensionless then raise syntax 93.900 array(label || ' must be dimensionless')
    if value~sourceUnit~family = 'RATIO' then return value~in(.Units~percent)
    return value~canonicalValue * 100
  end
  return value + 0


::method typed class
  /* Return a validated UnitQuantity while preserving its source/display unit.
   * Text is parsed by the shared Units authority; naked numerics use the
   * expected unit as their source unit for compatibility.
   */
  numeric digits 50
  use strict arg value, expectedUnit, label='quantity'
  if value~isA(.UnitQuantity) then do
    dummy = value~in(expectedUnit)
    return value
  end
  signal on syntax name tryText
  n = value + 0
  signal off syntax
  return .Units~q(n, expectedUnit)
tryText:
  signal off syntax
  signal on syntax name badTyped
  q = .Units~parseQuantity(value~string)
  dummy = q~in(expectedUnit)
  signal off syntax
  return q
badTyped:
  signal off syntax
  raise syntax 93.900 array(label || ' must be numeric, a UnitQuantity, or a parseable quantity compatible with ' || expectedUnit~symbol)

::method fromMetadata class
  /* Stable Units metadata is useful at Physics / persistence boundaries. */
  use strict arg metadata, expectedUnit=.nil, label='quantity'
  q = .Units~fromMetadata(metadata)
  if expectedUnit <> .nil then dummy = q~in(expectedUnit)
  return q

::requires 'Units.cls'
