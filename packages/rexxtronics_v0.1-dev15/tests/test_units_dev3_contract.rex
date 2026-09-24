numeric digits 50
failures = 0

/* Dev3 adds first-class engineering display scales used heavily by electronics. */
call near .Units~q(3.3, .Units~kilovolt)~in(.Units~volt), 3300, 'kV -> V'
call near .Units~q(250, .Units~microampere)~in(.Units~milliampere), 0.25, 'uA -> mA'
call near .Units~q(2.4, .Units~gigahertz)~in(.Units~megahertz), 2400, 'GHz -> MHz'
call near .Units~q(47, .Units~milliohm)~in(.Units~ohm), 0.047, 'mohm -> ohm'
call near .Units~q(330, .Units~microhenry)~in(.Units~millihenry), 0.33, 'uH -> mH'
call near .Units~q(15, .Units~microwatt)~in(.Units~milliwatt), 0.015, 'uW -> mW'

q1 = .Units~parseQuantity('220 uF')
call near q1~in(.Units~microfarad), 220, 'ASCII micro farad parser'
q2 = .Units~parseQuantity('250 µA')
call near q2~in(.Units~microampere), 250, 'Unicode micro ampere parser'
q3 = .Units~parseQuantity('2.4 GHz')
call near q3~in(.Units~megahertz), 2400, 'GHz parser'

/* Shared metadata schema must remain stable across the dependency increment. */
m = q2~metadata
if m['schema'] <> 'oorexx.units.quantity/0.1' then do
  say 'FAIL metadata schema:' m['schema']
  failures += 1
end
restored = .Units~fromMetadata(m)
call near restored~in(.Units~microampere), 250, 'dev3 metadata round-trip'

if failures = 0 then do
  say 'REXX-TRONICS UNITS DEV3 CONTRACT: OK'
  say '250 µA =' q2~in(.Units~milliampere) 'mA'
  say '2.4 GHz =' q3~in(.Units~megahertz) 'MHz'
  exit 0
end
say 'FAIL Units dev3 contract failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.000000000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

::requires 'RexxTronicsUnits.cls'
