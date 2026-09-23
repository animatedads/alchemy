numeric digits 50
failures=0

call checkNear .Units~convert(1,.Units~kilometre,.Units~metre),1000,'1 km = 1000 m'
call checkNear .Units~convert(1,.Units~inch,.Units~millimetre),'25.4','1 in = 25.4 mm'
call checkNear .Units~convert(60,.Units~milePerHour,.Units~kilometrePerHour),'96.56064','60 mph = 96.56064 km/h'

q=.UnitQuantity~new('4.7',.Units~kiloohm)
call checkNear q~in(.Units~ohm),4700,'4.7 kohm = 4700 ohm'
if q~sourceUnit~symbol <> 'kohm' then call fail 'source unit retained'
q~displayUnit=.Units~megaohm
call checkNear q~in(q~displayUnit),'0.0047','display unit independent of source'

v=.UnitQuantity~new(12,.Units~volt)
r=.UnitQuantity~new(4,.Units~ohm)
i=v/r
call checkNear i~canonicalValue,3,'V / ohm numeric value'
if i~dimension~canonical <> .Units~ampere~dimension~canonical then call fail 'V / ohm dimension = ampere'

mass=.UnitQuantity~new(2,.Units~kilogram)
acc=.UnitQuantity~new(3,.Units~metrePerSecondSquared)
force=mass*acc
call checkNear force~in(.Units~newton),6,'kg*m/s2 = N'

p=.Units~proof(1,.Units~inch,.Units~millimetre)
if \p~verifies then call fail 'conversion proof verifies'
call checkNear p~output,'25.4','proof output'

call checkNear .Units~convert(0,.Units~celsius,.Units~kelvin),'273.15','0 C = 273.15 K'
call checkNear .Units~convert(32,.Units~fahrenheit,.Units~celsius),0,'32 F = 0 C'
call checkNear .Units~convert(212,.Units~fahrenheit,.Units~celsius),100,'212 F = 100 C'

/* Equal SI dimension but semantically distinct photometric families must not silently convert. */
signal on syntax name expectedFamilyFailure
x=.UnitQuantity~new(1,.Units~candela)~in(.Units~lumen)
signal off syntax
call fail 'candela -> lumen should fail family compatibility'
expectedFamilyFailure:
signal off syntax

if failures=0 then do
  say 'PASS test_units'
  exit 0
end
say 'FAIL test_units failures='failures
exit 1

checkNear: procedure expose failures
  use arg actual,expected,label
  if abs(actual-expected) > '0.0000000000000000000000000000000000000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures+=1
  end
  return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
  return

::requires '../rexx/Units.cls'
