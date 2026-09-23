/* Qualification: instrument undersampling may alias, but circuit truth is retained. */
numeric digits 50

clock = .SimulationClock~new
net = .ElectricalNet~new('OSC')
osc = .DigitalOscillator~new('OSC1', clock, 500, 5, 0)
net~connect(osc~output)
osc~start
clock~runFor(.SimTime~fromMilliseconds(20))

if net~transitionCount < 20 then do
  say 'FAIL: authoritative transition history missing oscillator edges'
  exit 1
end

scope = .VirtualOscilloscope~new
poor = scope~acquire(net, .SimTime~fromMilliseconds(0), .SimTime~fromMilliseconds(20), 200)
if poor~samples~items < 4 then do
  say 'FAIL: undersampled scope acquisition malformed'
  exit 1
end

say 'REXX-TRONICS ALIASING BOUNDARY: OK'
say 'authoritative transitions:' net~transitionCount
say 'undersampled observations:' poor~samples~items
say 'poor-scope measured Hz:' poor~measuredFrequency(2.5)
exit 0


::requires 'RexxTronicsDevices.cls'
