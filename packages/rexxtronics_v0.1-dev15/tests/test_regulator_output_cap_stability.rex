numeric digits 50
failures=0

/* Qualification regulator profile only.  These loop values are deliberately
 * explicit test parameters, not a claim about an unnamed real regulator. */

/* Missing Cout case. */
c0=.Circuit~new
v0=c0~add(.DCVoltageSource~new('VIN','9 V'))
reg0=c0~add(.FeedbackLinearRegulator~new('REG','5 V',.Units~q(.0125,.Units~siemens),.Units~q(.2,.Units~siemens/.Units~volt),.Units~q(100,.Units~microsecond),.Units~q(100,.Units~microsecond),.Units~q(100,.Units~microsecond),.Units~q(.000001,.Units~siemens),.Units~q(1,.Units~siemens)))
load0=c0~add(.Resistor~new('LOAD1','100 ohm'))
sw0=c0~add(.Switch~new('LOADSTEP',.false))
load20=c0~add(.Resistor~new('LOAD2','100 ohm'))
c0~connectGround(v0~negative); c0~connectGround(reg0~reference); c0~connectGround(load0~pin('B')); c0~connectGround(load20~pin('B'))
c0~connect('VIN',.array~of(v0~positive,reg0~input))
c0~connect('OUT',.array~of(reg0~output,load0~pin('A'),sw0~pin('A')))
c0~connect('LOAD2TOP',.array~of(sw0~pin('B'),load20~pin('A')))
clock0=.SimulationClock~new
clock0~scheduleAt(.Units~q(5,.Units~millisecond),sw0,'CLOSE',.nil,'qualification load step')
run0=c0~simulateTransient(clock0,.Units~q(30,.Units~millisecond),.Units~q(100,.Units~microsecond))
scope=.VirtualOscilloscope~new
trace0=scope~acquireSignal(run0~signal('OUT'),.Units~q(15,.Units~millisecond),.Units~q(15,.Units~millisecond),.Units~q(10,.Units~kilohertz))
ripple0=trace0~maxVoltage-trace0~minVoltage

/* Same regulator and disturbance, now with an explicit external output capacitor. */
c1=.Circuit~new
v1=c1~add(.DCVoltageSource~new('VIN','9 V'))
reg1=c1~add(.FeedbackLinearRegulator~new('REG','5 V',.Units~q(.0125,.Units~siemens),.Units~q(.2,.Units~siemens/.Units~volt),.Units~q(100,.Units~microsecond),.Units~q(100,.Units~microsecond),.Units~q(100,.Units~microsecond),.Units~q(.000001,.Units~siemens),.Units~q(1,.Units~siemens)))
load1=c1~add(.Resistor~new('LOAD1','100 ohm'))
sw1=c1~add(.Switch~new('LOADSTEP',.false))
load21=c1~add(.Resistor~new('LOAD2','100 ohm'))
cout=c1~add(.Capacitor~new('COUT','100 uF','5 V'))
c1~connectGround(v1~negative); c1~connectGround(reg1~reference); c1~connectGround(load1~pin('B')); c1~connectGround(load21~pin('B')); c1~connectGround(cout~pin('B'))
c1~connect('VIN',.array~of(v1~positive,reg1~input))
c1~connect('OUT',.array~of(reg1~output,load1~pin('A'),sw1~pin('A'),cout~pin('A')))
c1~connect('LOAD2TOP',.array~of(sw1~pin('B'),load21~pin('A')))
clock1=.SimulationClock~new
clock1~scheduleAt(.Units~q(5,.Units~millisecond),sw1,'CLOSE',.nil,'qualification load step')
run1=c1~simulateTransient(clock1,.Units~q(30,.Units~millisecond),.Units~q(100,.Units~microsecond))
trace1=scope~acquireSignal(run1~signal('OUT'),.Units~q(15,.Units~millisecond),.Units~q(15,.Units~millisecond),.Units~q(10,.Units~kilohertz))
ripple1=trace1~maxVoltage-trace1~minVoltage
final1=run1~voltageAt('OUT',.Units~q(30,.Units~millisecond))


/* Control case proving that Cout=0 is not hard-coded as unstable.  The same
 * component with a lower loop gain remains settled without an output capacitor. */
c2=.Circuit~new
v2=c2~add(.DCVoltageSource~new('VIN','9 V'))
reg2=c2~add(.FeedbackLinearRegulator~new('REG','5 V',.Units~q(.0125,.Units~siemens),.Units~q(.05,.Units~siemens/.Units~volt),.Units~q(100,.Units~microsecond),.Units~q(100,.Units~microsecond),.Units~q(100,.Units~microsecond),.Units~q(.000001,.Units~siemens),.Units~q(1,.Units~siemens)))
load2a=c2~add(.Resistor~new('LOAD1','100 ohm'))
sw2=c2~add(.Switch~new('LOADSTEP',.false))
load2b=c2~add(.Resistor~new('LOAD2','100 ohm'))
c2~connectGround(v2~negative); c2~connectGround(reg2~reference); c2~connectGround(load2a~pin('B')); c2~connectGround(load2b~pin('B'))
c2~connect('VIN',.array~of(v2~positive,reg2~input))
c2~connect('OUT',.array~of(reg2~output,load2a~pin('A'),sw2~pin('A')))
c2~connect('LOAD2TOP',.array~of(sw2~pin('B'),load2b~pin('A')))
clock2=.SimulationClock~new
clock2~scheduleAt(.Units~q(5,.Units~millisecond),sw2,'CLOSE',.nil,'qualification load step')
run2=c2~simulateTransient(clock2,.Units~q(30,.Units~millisecond),.Units~q(100,.Units~microsecond))
trace2=scope~acquireSignal(run2~signal('OUT'),.Units~q(15,.Units~millisecond),.Units~q(15,.Units~millisecond),.Units~q(10,.Units~kilohertz))
ripple2=trace2~maxVoltage-trace2~minVoltage

if ripple0<2 then call fail 'missing-Cout qualification did not expose the modeled loop oscillation'
if ripple1>.1 then call fail '100 uF qualification output did not settle'
if abs(final1-5)>.15 then call fail '100 uF qualification output did not regulate near 5 V'
if trace0~minVoltage<-.001 | trace0~maxVoltage>9.001 then call fail 'missing-Cout waveform escaped physical supply bounds'
if ripple2>.01 then call fail 'benign no-Cout control profile was incorrectly forced unstable'

if failures=0 then do
  say 'REXX-TRONICS REGULATOR OUTPUT-CAPACITOR STABILITY: OK'
  say 'modeled regulator: target=5 V, Vin=9 V, three 100 us control poles'
  say 'load step: 100 ohm -> 50 ohm at 5 ms'
  say 'Cout=0 late min/max V:' trace0~minVoltage trace0~maxVoltage
  say 'Cout=0 late peak-to-peak V:' ripple0
  say 'Cout=100 uF late min/max V:' trace1~minVoltage trace1~maxVoltage
  say 'Cout=100 uF late peak-to-peak V:' ripple1
  say 'Cout=100 uF final V:' final1
  say 'benign profile, Cout=0 late peak-to-peak V:' ripple2
  exit 0
end
say 'FAIL regulator output-capacitor stability failures='failures
exit 1

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures+=1
return

::requires 'RexxTronicsRegulators.cls'
::requires 'RexxTronicsDevices.cls'
