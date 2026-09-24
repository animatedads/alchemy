/* Qualification: a 500 Hz circuit remains 500 Hz in simulation time. */
numeric digits 50

clock = .SimulationClock~new
net = .ElectricalNet~new('OSC')
osc = .DigitalOscillator~new('OSC1', clock, 500, 5, 0)
net~connect(osc~output)
osc~start

clock~runFor(.SimTime~fromMilliseconds(20))

scope = .VirtualOscilloscope~new
trace = scope~acquire(net, .SimTime~fromMilliseconds(0), .SimTime~fromMilliseconds(20), 50000)
f = trace~measuredFrequency(2.5)

if f == .nil then do
  say 'FAIL: no frequency measured'
  exit 1
end
if abs(f - 500) > 0.01 then do
  say 'FAIL: expected 500 Hz, got' f
  exit 1
end
if trace~minVoltage <> 0 then do
  say 'FAIL: expected 0 V trough, got' trace~minVoltage
  exit 1
end
if trace~maxVoltage <> 5 then do
  say 'FAIL: expected 5 V peak, got' trace~maxVoltage
  exit 1
end
if clock~nowPs <> .SimTime~fromMilliseconds(20)~picoseconds then do
  say 'FAIL: simulation clock did not end at 20 ms'
  exit 1
end

say 'REXX-TRONICS SIMULATION TIME: OK'
say 'simulated elapsed ms:' clock~now~milliseconds
say 'measured oscillator Hz:' f
say 'scope samples:' trace~samples~items
say 'net transitions:' net~transitionCount
exit 0


::requires 'RexxTronicsDevices.cls'
