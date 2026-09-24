numeric digits 40
failures=0
clock=.SimulationClock~new
c=.Circuit~new
v=c~add(.SineVoltageSource~new('VS','1 V','2 V','1 kHz'))
r=c~add(.Resistor~new('R','1 kOhm'))
c~connect('OUT',.array~of(v~positive,r~pin('A')))
c~connectGround(v~negative); c~connectGround(r~pin('B'))
run=c~simulateTransient(clock,'2.1 ms','0.01 ms')
call near run~voltageAt('OUT','0.25 ms'),3,'positive peak','0.000001'
call near run~voltageAt('OUT','0.75 ms'),-1,'negative peak','0.000001'
scope=.VirtualOscilloscope~new
trace=scope~acquireSignal(run~signal('OUT'),'0 ms','2.1 ms','100 kHz')
call near trace~measuredFrequency('1 V'),1000,'scope sine frequency','0.1'
if failures=0 then do
  say 'REXX-TRONICS SINE VOLTAGE SOURCE: OK'
  say 'measured frequency Hz:' trace~measuredFrequency('1 V')
  say 'scope min/max V:' trace~minVoltage trace~maxVoltage
  exit 0
end
say 'FAIL sine source failures='failures
exit 1
near: procedure expose failures
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures+=1
  end
return
::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsDevices.cls'
