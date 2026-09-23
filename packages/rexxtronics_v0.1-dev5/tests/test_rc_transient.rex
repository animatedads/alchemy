/* Qualification: RC charging is solved in simulation time, independent of wall time. */
numeric digits 50

clock = .SimulationClock~new
c = .Circuit~new
source = c~add(.StepVoltageSource~new('V1', 0, 5, .SimTime~fromMilliseconds(1)))
r = c~add(.Resistor~new('R1', 1000))
cap = c~add(.Capacitor~new('C1', 0.000001, 0))

c~connect('VCC', .array~of(source~positive, r~pin('A')))
c~connect('RC', .array~of(r~pin('B'), cap~pin('A')))
c~connectGround(cap~pin('B'))
c~connectGround(source~negative)

result = c~simulateTransient(clock, .SimTime~fromMilliseconds(6), .SimTime~fromMicroseconds(10))

atStart = result~voltageAt('RC', .SimTime~fromMilliseconds(0))
atOneTau = result~voltageAt('RC', .SimTime~fromMilliseconds(2))
atFiveTau = result~voltageAt('RC', .SimTime~fromMilliseconds(6))

if abs(atStart) > 0.000001 then do
  say 'FAIL: RC initial voltage expected 0 V, got' atStart
  exit 1
end
if abs(atOneTau - 3.1606) > 0.04 then do
  say 'FAIL: RC one-tau voltage expected about 3.16 V, got' atOneTau
  exit 1
end
if atFiveTau < 4.96 | atFiveTau > 5.001 then do
  say 'FAIL: RC five-tau voltage expected near 5 V, got' atFiveTau
  exit 1
end
if clock~nowPs <> .SimTime~fromMilliseconds(6)~picoseconds then do
  say 'FAIL: transient clock ended at wrong simulation time'
  exit 1
end

scope = .VirtualOscilloscope~new
trace = scope~acquireSignal(result~signal('RC'), .SimTime~fromMilliseconds(0), .SimTime~fromMilliseconds(6), 100000)
if trace~maxVoltage < 4.96 then do
  say 'FAIL: scope did not observe RC charge'
  exit 1
end

say 'REXX-TRONICS RC TRANSIENT: OK'
say 'RC at t=0 ms:' atStart 'V'
say 'RC at t=2 ms (1 tau after step):' atOneTau 'V'
say 'RC at t=6 ms (5 tau after step):' atFiveTau 'V'
say 'transient points:' result~pointCount
exit 0

::requires 'RexxTronicsDevices.cls'
::requires 'RexxTronicsTransient.cls'
