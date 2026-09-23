numeric digits 50
failures = 0

if .Units~version <> '0.1-dev2' then call fail 'expected shared Units v0.1-dev2'

/* dev2 closes the precision leakage found by Rexx-tronics dev4. */
preciseText = '3.1697464752475247524752475247524752475'
precise = .Units~q(preciseText, .Units~volt)
if precise~canonicalValue <> preciseText then call fail '50-digit UnitQuantity construction changed the supplied scalar'

/* Rexx-tronics accepts Units dev2 textual quantities at electrical boundaries. */
r = .Resistor~new('RTXT', '4.7 kΩ')
call near r~resistance~in(.Units~ohm), 4700, 'unicode/text resistance'
c = .Capacitor~new('CTXT', '220 nF')
call near c~capacitance~in(.Units~nanofarad), 220, 'text capacitance'
l = .Inductor~new('LTXT', '10 mH')
call near l~inductance~in(.Units~millihenry), 10, 'text inductance'
v = .DCVoltageSource~new('VTXT', '250 mV')
call near v~voltage~in(.Units~millivolt), 250, 'text voltage'

/* Simulation-time text goes through the same Units authority. */
clock = .SimulationClock~new
clock~runFor('2 ms')
if clock~nowPs <> 2000000000 then call fail 'text time did not resolve to 2 ms'

/* Metadata is the stable cross-library/persistence shape supplied by Units dev2. */
original = .RexxTronicsUnits~typed('4.7 kΩ', .Units~ohm, 'resistance')
metadata = original~metadata
restored = .RexxTronicsUnits~fromMetadata(metadata, .Units~ohm, 'resistance')
call near restored~in(.Units~ohm), 4700, 'quantity metadata round trip'
if metadata['schema'] <> 'oorexx.units.quantity/0.1' then call fail 'quantity metadata schema'
if metadata['unitsVersion'] <> '0.1-dev2' then call fail 'quantity metadata unitsVersion'
if restored~sourceUnit~symbol <> 'kohm' then call fail 'quantity source unit provenance not retained'

/* Textual quantities are still fail-closed on dimension. */
signal on syntax name expectedBadDimension
bad = .Resistor~new('BADTXT', '5 V')
signal off syntax
call fail 'text voltage accepted as resistance'
expectedBadDimension:
signal off syntax

if failures = 0 then do
  say 'REXX-TRONICS UNITS DEV2 CONTRACT: OK'
  say 'precision:' precise~canonicalValue
  say 'parsed resistance:' r~resistance~in(.Units~kiloohm) 'kOhm'
  say 'metadata schema:' metadata['schema']
  exit 0
end
say 'FAIL Units dev2 contract failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.0000000000000000000000000000000000000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures += 1
  return

::requires 'RexxTronicsDevices.cls'
::requires 'RexxTronicsTransient.cls'
