numeric digits 50
failures = 0

/* Mixed-unit DC construction: 9 V source, 1 kohm / 2 kohm divider. */
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', .Units~q(9000, .Units~millivolt)))
r1 = c~add(.Resistor~new('R1', .Units~q(1, .Units~kiloohm), .Units~q(5, .Units~percent), .Units~q(250, .Units~watt) / 1000))
r2 = c~add(.Resistor~new('R2', .Units~q(0.002, .Units~megaohm)))
c~connect('VCC', .array~of(v~positive, r1~pin('A')))
c~connect('MID', .array~of(r1~pin('B'), r2~pin('A')))
c~connectGround(r2~pin('B'))
c~connectGround(v~negative)
sol = c~solveDC
call near sol~voltageQuantity('VCC')~in(.Units~millivolt), 9000, 'VCC in mV'
call near sol~voltageQuantity('MID')~in(.Units~volt), 6, 'MID in V'
call near sol~currentQuantity('R1')~in(.Units~milliampere), 3, 'R1 current in mA'
call near r1~resistance~in(.Units~ohm), 1000, 'R1 resistance quantity'
call near r2~resistance~in(.Units~kiloohm), 2, 'R2 resistance quantity'

/* Time, frequency and voltage quantities cross the event/instrument boundary. */
clock = .SimulationClock~new
net = .ElectricalNet~new('CLOCK', .Units~q(0, .Units~millivolt))
osc = .DigitalOscillator~new('OSC', clock, .Units~q(0.5, .Units~kilohertz), .Units~q(5000, .Units~millivolt), .Units~q(0, .Units~millivolt))
net~connect(osc~output)
osc~start
clock~runFor(.Units~q(20, .Units~millisecond))
scope = .VirtualOscilloscope~new
trace = scope~acquire(net, .Units~q(0, .Units~millisecond), .Units~q(20, .Units~millisecond), .Units~q(50, .Units~kilohertz))
call near trace~measuredFrequencyQuantity~in(.Units~hertz), 500, 'scope measured frequency'
call near trace~maxVoltageQuantity~in(.Units~millivolt), 5000, 'scope peak mV'
call near trace~sampleInterval~in(.Units~microsecond), 20, 'scope interval us'

/* Transient solver accepts non-SI user-facing quantities directly. */
clock2 = .SimulationClock~new
ct = .Circuit~new
sv = ct~add(.StepVoltageSource~new('VSTEP', .Units~q(0,.Units~volt), .Units~q(5000,.Units~millivolt), .Units~q(1,.Units~millisecond)))
rr = ct~add(.Resistor~new('R', .Units~q(1,.Units~kiloohm)))
cc = ct~add(.Capacitor~new('C', .Units~q(1,.Units~microfarad), .Units~q(0,.Units~volt)))
ct~connect('VCC', .array~of(sv~positive, rr~pin('A')))
ct~connect('RC', .array~of(rr~pin('B'), cc~pin('A')))
ct~connectGround(cc~pin('B'))
ct~connectGround(sv~negative)
run = ct~simulateTransient(clock2, .Units~q(6,.Units~millisecond), .Units~q(10,.Units~microsecond))
call near run~voltageAtQuantity('RC', .Units~q(2,.Units~millisecond), .Units~millivolt)~in(.Units~millivolt), '3169.7464752475247524752475247524752475247524752476', 'RC transient mV'

/* Dimension mismatch must fail closed rather than silently taking the number. */
signal on syntax name expectedBadDimension
bad = .Resistor~new('BAD', .Units~q(5, .Units~volt))
signal off syntax
call fail 'voltage quantity accepted as resistance'
expectedBadDimension:
signal off syntax

if failures = 0 then do
  say 'REXX-TRONICS SHARED UNITS INTEGRATION: OK'
  say 'MID:' sol~voltageQuantity('MID')~in(.Units~volt) 'V'
  say 'R1 current:' sol~currentQuantity('R1')~in(.Units~milliampere) 'mA'
  say 'scope:' trace~measuredFrequencyQuantity~in(.Units~hertz) 'Hz'
  say 'RC at 2 ms:' run~voltageAtQuantity('RC', .Units~q(2,.Units~millisecond))~in(.Units~volt) 'V'
  exit 0
end
say 'FAIL shared Units integration failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.00001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

fail: procedure expose failures
  use arg label
  say 'FAIL:' label
  failures += 1
  return

::requires 'RexxTronicsDevices.cls'
::requires 'RexxTronicsTransient.cls'
