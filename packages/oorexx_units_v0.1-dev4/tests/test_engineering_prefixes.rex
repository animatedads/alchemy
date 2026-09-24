numeric digits 50
failures=0
call check .Units~q('0.000625',.Units~watt)~in(.Units~milliwatt), '0.625', 'W -> mW'
call check .Units~parseQuantity('625 uW')~in(.Units~milliwatt), '0.625', 'uW -> mW'
call check .Units~parseQuantity('0.625 mW')~in(.Units~microwatt), '625', 'mW -> uW'
call check .Units~parseQuantity('3.3 kV')~in(.Units~volt), '3300', 'kV -> V'
call check .Units~parseQuantity('250 uA')~in(.Units~milliampere), '0.25', 'uA -> mA'
call check .Units~parseQuantity('47 mF')~in(.Units~microfarad), '47000', 'mF -> uF'
call check .Units~parseQuantity('22 uH')~in(.Units~millihenry), '0.022', 'uH -> mH'
call check .Units~parseQuantity('2.4 GHz')~in(.Units~megahertz), '2400', 'GHz -> MHz'
if failures=0 then say 'PASS test_engineering_prefixes'
else do; say 'FAIL test_engineering_prefixes' failures; exit 1; end
exit 0
check: procedure expose failures
  use arg actual,expected,label
  /* Numeric equality: representation (3300 vs 3300.0) is not quantity inequality. */
  if actual = expected then return
  failures += 1
  say 'FAIL' label 'actual='actual 'expected='expected
return
::requires '../rexx/Units.cls'
