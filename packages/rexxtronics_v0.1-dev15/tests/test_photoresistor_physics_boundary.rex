/* Qualification: typed Physics-style illuminance observations drive an
 * electrical photoresistor without sharing any wall-clock semantics.
 */
numeric digits 50
failures = 0

points = .array~new
points~append(.LightResistancePoint~new(.Units~q(0, .Units~lux), '1 Mohm'))
points~append(.LightResistancePoint~new(.Units~q(100, .Units~lux), '10 kohm'))
points~append(.LightResistancePoint~new(.Units~q(1000, .Units~lux), '1 kohm'))
curve = .LightResistanceCurve~new(points)

ldr = .PhotoResistor~new('LDR1', curve, .Units~q(100, .Units~lux))
call near ldr~resistance~in(.Units~kiloohm), 10, 'initial LDR resistance'

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '5 V'))
r = c~add(.Resistor~new('R1', '10 kohm'))
c~add(ldr)
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('SENSE', .array~of(r~pin('B'), ldr~pin('A')))
c~connectGround(ldr~pin('B'))
c~connectGround(v~negative)

sol1 = c~solveDC
call near sol1~voltageQuantity('SENSE')~in(.Units~volt), 2.5, '100 lx divider voltage'

obs = .IlluminanceObservation~new(.Units~q(1000, .Units~lux), '2 ms', 'physics mirror/prism propagation', 'PhysicsWorld')
ldr~applyObservation(obs)
call near ldr~illuminance~in(.Units~lux), 1000, 'observation illuminance'
call near ldr~resistance~in(.Units~kiloohm), 1, '1000 lx LDR resistance'
call near ldr~lastStimulusTime~in(.Units~millisecond), 2, 'observation simulation time'
if ldr~lastStimulusCause <> 'physics mirror/prism propagation' then do
  say 'FAIL stimulus cause was not retained'
  failures += 1
end
sol2 = c~solveDC
call near sol2~voltageQuantity('SENSE')~in(.Units~volt), 5/11, '1000 lx divider voltage'

/* The same physical observation can arrive as a scheduled event on the
 * authoritative simulation clock. */
clock = .SimulationClock~new
ldr~applyIlluminance(.Units~q(100, .Units~lux), '0 ms', 'initial condition')
ldr~scheduleIlluminance(clock, '2 ms', .Units~q(1000, .Units~lux), 'scheduled Physics observation')
run = c~simulateTransient(clock, '4 ms', '0.1 ms')
call near run~voltageAtQuantity('SENSE', '1.9 ms')~in(.Units~volt), 2.5, 'before Physics event'
call near run~voltageAtQuantity('SENSE', '2.1 ms')~in(.Units~volt), 5/11, 'after Physics event'
call near ldr~lastStimulusTime~in(.Units~millisecond), 2, 'scheduled stimulus simulation time'

/* The generic sensor must not extrapolate beyond datasheet/model evidence. */
signal on syntax name expectedRangeFailure
bad = curve~resistanceFor(.Units~q(2000, .Units~lux))
signal off syntax
say 'FAIL response curve extrapolated without authority'
failures += 1
expectedRangeFailure:
signal off syntax

if failures = 0 then do
  say 'REXX-TRONICS PHOTORESISTOR / PHYSICS BOUNDARY: OK'
  say '100 lx SENSE:' sol1~voltageQuantity('SENSE')~in(.Units~volt) 'V'
  say '1000 lx SENSE:' sol2~voltageQuantity('SENSE')~in(.Units~volt) 'V'
  say 'scheduled observation time:' ldr~lastStimulusTime~in(.Units~millisecond) 'ms'
  exit 0
end
say 'FAIL photoresistor Physics boundary failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.00001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

::requires 'RexxTronicsSensors.cls'
::requires 'RexxTronicsTransient.cls'
