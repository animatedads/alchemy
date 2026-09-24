/* Qualification: discrete switch events and transient solving share one simulation clock. */
numeric digits 50

clock = .SimulationClock~new
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', 5))
sw = c~add(.Switch~new('S1', .false))
r = c~add(.Resistor~new('R1', 1000))

c~connect('VCC', .array~of(v~positive, sw~pin('A')))
c~connect('OUT', .array~of(sw~pin('B'), r~pin('A')))
c~connectGround(r~pin('B'))
c~connectGround(v~negative)

clock~scheduleAt(.SimTime~fromMilliseconds(2), sw, 'CLOSE')
result = c~simulateTransient(clock, .SimTime~fromMilliseconds(4), .SimTime~fromMicroseconds(100))

before = result~voltageAt('OUT', .SimTime~fromMilliseconds(1.9))
after = result~voltageAt('OUT', .SimTime~fromMilliseconds(2.1))
if before > 0.00001 then do
  say 'FAIL: OUT should be low before scheduled switch close, got' before
  exit 1
end
if abs(after - 5) > 0.001 then do
  say 'FAIL: OUT should be high after scheduled switch close, got' after
  exit 1
end

say 'REXX-TRONICS SCHEDULED SWITCH TRANSIENT: OK'
say 'before close:' before 'V'
say 'after close:' after 'V'
exit 0

::requires 'RexxTronicsTransient.cls'
