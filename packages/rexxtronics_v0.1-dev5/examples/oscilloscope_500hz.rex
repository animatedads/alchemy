numeric digits 50
clock = .SimulationClock~new
net = .ElectricalNet~new('CLOCK')
osc = .DigitalOscillator~new('U1.CLK', clock, 500, 5, 0)
net~connect(osc~output)
osc~start
clock~runFor(.SimTime~fromMilliseconds(10))

scope = .VirtualOscilloscope~new
trace = scope~acquire(net, .SimTime~fromMilliseconds(0), .SimTime~fromMilliseconds(10), 50000)

say 'frequency:' trace~measuredFrequency(2.5) 'Hz'
say 'peak:' trace~maxVoltage 'V'
say 'trough:' trace~minVoltage 'V'
say 'simulation time:' clock~now~milliseconds 'ms'


::requires 'RexxTronicsDevices.cls'
