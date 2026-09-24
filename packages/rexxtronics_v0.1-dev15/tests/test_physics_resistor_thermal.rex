numeric digits 40
failures=0

/* 10 V across 10 ohm -> 10 W.  Explicitly project that dissipated power into
 * a 100 J/K Physics thermal node for 2 seconds: Delta T = 0.2 K. */
c=.Circuit~new
v=c~add(.DCVoltageSource~new('V1','10 V'))
r=c~add(.Resistor~new('RHEAT','10 ohm'))
c~connect('HOT',.array~of(v~positive,r~pin('A')))
c~connectGround(v~negative); c~connectGround(r~pin('B'))
solution=c~solveDC
call near solution~power(r),10,'electrical resistor power','0.000000001'

node=.ThermalNode~new('RHEAT-THERMAL',.Units~q(300,.Units~kelvin),.Units~q(100,.Units~joule/.Units~deltaKelvin))
thermal=.ThermalSolver~new
thermal~addNode(node)
if node~pendingPower<>0 then call fail 'thermal node must not receive electrical power without an explicit bridge'

bridge=.ElectricalThermalPowerBridge~new(r,node)
obs=bridge~observeFromSolution(solution,'0 s','resistor Joule heat qualification')
call near obs~power,10,'typed thermal observation power','0.000000001'
if obs~source<>r then call fail 'thermal observation did not retain electrical source'
if obs~evidence<>solution then call fail 'thermal observation did not retain electrical solution evidence'
thermal~step(.Units~q(2,.Units~second))
call near node~temperatureKelvin,300.2,'temperature after explicit 20 J deposition','0.000000001'

if failures=0 then do
  say 'REXX-TRONICS / PHYSICS EXPLICIT RESISTOR HEAT: OK'
  say 'electrical power W:' solution~power(r)
  say 'temperature K:' node~temperatureKelvin
  exit 0
end
say 'FAIL resistor thermal failures='failures
exit 1

near: procedure expose failures
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures+=1
  end
return
fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
return

::requires 'RexxTronicsThermal.cls'
