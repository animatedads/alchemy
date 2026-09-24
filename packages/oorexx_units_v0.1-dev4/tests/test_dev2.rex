numeric digits 50
failures=0

t1=.Units~q(25,.Units~celsius)
t2=.Units~q(20,.Units~celsius)
d=t1-t2
call checkNear d~in(.Units~deltaCelsius),5,'25 C - 20 C = delta 5 C'
if \d~isTemperatureDelta then call fail 'absolute temperature subtraction yields delta'
call checkNear d~in(.Units~deltaFahrenheit),9,'delta 5 C = delta 9 F'
t3=t2+d
call checkNear t3~in(.Units~celsius),25,'20 C + delta 5 C = 25 C'

signal on syntax name expectedAbsAddFailure
dummy=t1+t2
signal off syntax
call fail 'absolute + absolute temperature should fail'
expectedAbsAddFailure:
signal off syntax

kmPerHour=.Units~kilometre/.Units~hour
call checkNear kmPerHour~scale,'0.27777777777777777777777777777777777777777777777778','constructed km/h scale'
if kmPerHour~dimension~canonical <> .Units~metrePerSecond~dimension~canonical then call fail 'constructed km/h dimension'
area=.Units~centimetre~power(2)
call checkNear area~scale,'0.0001','cm^2 scale'
if area~dimension~canonical <> .Units~squareMetre~dimension~canonical then call fail 'area dimension'

q=.Units~parseQuantity('4.7 kohm')
call checkNear q~in(.Units~ohm),4700,'parse 4.7 kohm'
if .Units~unit('mV')~symbol <> 'mV' then call fail 'resolve mV'
uv=.Units~prefixed(.Units~volt,'micro','u','0.000001')
call checkNear .Units~convert(2,uv,.Units~volt),'0.000002','prefix factory microvolt'

call checkNear .Units~convert(1,.Units~litre,.Units~cubicMetre),'0.001','litre to cubic metre'
call checkNear .Units~convert(1,.Units~gramPerCubicCentimetre,.Units~kilogramPerCubicMetre),1000,'density conversion'
call checkNear .Units~convert(1,.Units~bar,.Units~pascal),100000,'bar to Pa'
call checkNear .Units~convert(1,.Units~electronvolt,.Units~joule),'0.0000000000000000001602176634','electronvolt exact SI definition'

parsedForce=.Units~parseUnit('kg*m/s^2')
if parsedForce~dimension~canonical <> .Units~newton~dimension~canonical then call fail 'parse compound force dimension'
call checkNear parsedForce~scale,1,'parse compound force scale'
parsedDensity=.Units~parseQuantity('1 g/cm^3')
call checkNear parsedDensity~in(.Units~kilogramPerCubicMetre),1000,'parse compound density quantity'
parsedResistance=.Units~parseQuantity('4.7 kΩ')
call checkNear parsedResistance~in(.Units~ohm),4700,'unicode ohm alias'
parsedTemp=.Units~parseQuantity('25 °C')
call checkNear parsedTemp~in(.Units~kelvin),'298.15','unicode Celsius alias'

angle=.Units~q(1,.Units~radian)
ratio=.Units~q(1,.Units~one)
if angle = ratio then call fail 'dimensionless semantic families must not compare equal'

m=.Units~q(4.7,.Units~kiloohm,.Units~ohm)~metadata
if m['sourceUnit'] <> 'kohm' then call fail 'metadata source unit'
if m['displayUnit'] <> 'ohm' then call fail 'metadata display unit'
call checkNear m['canonicalValue'],4700,'metadata canonical value'
restored=.Units~fromMetadata(m)
call checkNear restored~in(.Units~ohm),4700,'metadata round trip value'
if restored~sourceUnit~symbol <> 'kohm' then call fail 'metadata round trip source unit'
if restored~displayUnit~symbol <> 'ohm' then call fail 'metadata round trip display unit'
if m['schema'] <> 'oorexx.units.quantity/0.1' then call fail 'metadata schema'
if .Units~version <> '0.1-dev4' then call fail 'Units version'

if failures=0 then do; say 'PASS test_dev2'; exit 0; end
say 'FAIL test_dev2 failures='failures; exit 1

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
