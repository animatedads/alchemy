numeric digits 50
failures=0
force=.Units~kilogram~dimension*.Units~metre~dimension/.Units~second~dimension~power(2)
if force~canonical <> .Units~newton~dimension~canonical then call fail 'force dimension'
voltage=.Units~watt~dimension/.Units~ampere~dimension
if voltage~canonical <> .Units~volt~dimension~canonical then call fail 'voltage = power/current'
resistance=.Units~volt~dimension/.Units~ampere~dimension
if resistance~canonical <> .Units~ohm~dimension~canonical then call fail 'resistance = voltage/current'
capacitance=.Units~coulomb~dimension/.Units~volt~dimension
if capacitance~canonical <> .Units~farad~dimension~canonical then call fail 'capacitance = charge/voltage'
if failures=0 then do; say 'PASS test_dimensions'; exit 0; end
say 'FAIL test_dimensions failures='failures; exit 1
fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
  return
::requires '../rexx/Units.cls'
