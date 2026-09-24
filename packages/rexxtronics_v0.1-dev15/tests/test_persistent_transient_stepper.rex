numeric digits 50
failures=0

/* Persistent stepping must reproduce the same R-L trajectory as a one-shot
 * transient run without reinitialising the inductor at partition boundaries. */
clock=.SimulationClock~new
c=.Circuit~new
v=c~add(.StepVoltageSource~new('VSTEP','0 V','5 V','0 ms'))
r=c~add(.Resistor~new('R','1 kΩ'))
l=c~add(.Inductor~new('L','1 H','0 A'))
c~connect('VCC',.array~of(v~positive,r~pin('A')))
c~connect('RL',.array~of(r~pin('B'),l~pin('A')))
c~connectGround(l~pin('B'))
c~connectGround(v~negative)

stepper=c~newTransientStepper(clock)
initial=stepper~begin('0.01 ms')
call near l~storedCurrent~in(.Units~milliampere),0,'initial inductor history','0.000000001'

do 100
  s=stepper~step('0.01 ms')
end
persistent=s~current(l)*1000
stored=l~storedCurrent~in(.Units~milliampere)
if clock~now~milliseconds<>1 then call fail 'persistent stepper clock did not reach 1 ms'
if stepper~result~pointCount<>101 then call fail 'persistent stepper result did not retain all points'
call near stored,persistent,'inductor stored current tracks final stepped solution','0.000000001'

/* Independent one-shot reference. */
clock2=.SimulationClock~new
c2=.Circuit~new
v2=c2~add(.StepVoltageSource~new('VSTEP','0 V','5 V','0 ms'))
r2=c2~add(.Resistor~new('R','1 kΩ'))
l2=c2~add(.Inductor~new('L','1 H','0 A'))
c2~connect('VCC',.array~of(v2~positive,r2~pin('A')))
c2~connect('RL',.array~of(r2~pin('B'),l2~pin('A')))
c2~connectGround(l2~pin('B'))
c2~connectGround(v2~negative)
run=c2~simulateTransient(clock2,'1 ms','0.01 ms')
reference=run~currentAtQuantity(l2,'1 ms')~in(.Units~milliampere)
call near persistent,reference,'persistent stepper equals one-shot transient','0.000000001'

if failures=0 then do
  say 'REXX-TRONICS PERSISTENT TRANSIENT STEPPER: OK'
  say 'current at 1 ms mA:' persistent
  say 'retained points:' stepper~result~pointCount
  exit 0
end
say 'FAIL persistent transient stepper failures='failures
exit 1

near: procedure expose failures
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected 'tolerance='tolerance
    failures+=1
  end
return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
return

::requires 'RexxTronicsTransient.cls'
