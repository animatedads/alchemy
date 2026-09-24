numeric digits 50
failures=0
call check .Units~parseQuantity('32 psi')~in(.Units~kilopascal), '220.6322333813875627751255502511004893975989486336', 'psi -> kPa'
call check .Units~parseQuantity('500 cc')~in(.Units~millilitre), '500', 'cc -> mL'
call check .Units~parseQuantity('1 UK gal')~in(.Units~litre), '4.54609', 'UK gallon -> L'
call check .Units~parseQuantity('1 US gal')~in(.Units~litre), '3.785411784', 'US gallon -> L'
call check .Units~parseQuantity('100 kph')~in(.Units~milePerHour), '62.137119223733396961743418436331822158593812137120', 'kph -> mph'
call check .Units~parseQuantity('1 hp')~in(.Units~watt), '745.69987158227022', 'hp -> W'
call check .Units~parseQuantity('1 PS')~in(.Units~watt), '735.49875', 'PS -> W'
call check .Units~parseQuantity('1 nmi')~in(.Units~metre), '1852', 'nautical mile -> metre'
call check .Units~parseQuantity('1 kn')~in(.Units~kilometrePerHour), '1.852', 'knot -> km/h'
call check .Units~parseQuantity('1 acre')~in(.Units~squareMetre), '4046.8564224', 'acre -> m^2'
call check .Units~parseQuantity('1 BTU')~in(.Units~joule), '1055.05585262', 'BTU -> J'
call ambiguousGallon
if failures=0 then say 'PASS test_practical_units'
else do; say 'FAIL test_practical_units' failures; exit 1; end
exit 0

check: procedure expose failures
  use arg actual,expected,label
  /* Relative tolerance only for conversion chains whose decimal representation repeats. */
  delta=abs(actual-expected)
  scale=abs(expected); if scale < 1 then scale=1
  if delta/scale < 0.0000000000000000000000000000000000000001 then return
  failures += 1
  say 'FAIL' label 'actual='actual 'expected='expected
return

ambiguousGallon: procedure expose failures
  signal on syntax name expectedFailure
  u=.Units~parseUnit('gallon')
  signal off syntax
  failures += 1
  say 'FAIL bare gallon should be rejected, got' u
  return
expectedFailure:
  signal off syntax
return

::requires '../rexx/Units.cls'
