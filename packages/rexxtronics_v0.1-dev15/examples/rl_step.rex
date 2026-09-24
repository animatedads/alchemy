numeric digits 50
clock = .SimulationClock~new
c = .Circuit~new
v = c~add(.StepVoltageSource~new('VSTEP', '0 V', '5 V', '1 ms'))
r = c~add(.Resistor~new('R1', '1 kΩ'))
l = c~add(.Inductor~new('L1', '1 H'))
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('RL', .array~of(r~pin('B'), l~pin('A')))
c~connectGround(l~pin('B'))
c~connectGround(v~negative)
run = c~simulateTransient(clock, '6 ms', '0.01 ms')
say 't=2ms current:' run~currentAtQuantity(l, '2 ms', .Units~milliampere)
say 't=6ms current:' run~currentAtQuantity(l, '6 ms', .Units~milliampere)
say 'stored energy:' l~storedEnergy~as(.Units~joule)
::requires 'RexxTronicsTransient.cls'
