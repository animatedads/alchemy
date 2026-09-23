/* Rexx-tronics RC charge example: 5 V step into 1 kOhm / 1 uF. */
numeric digits 50
clock = .SimulationClock~new
circuit = .Circuit~new
v = circuit~add(.StepVoltageSource~new('V1', 0, 5, .SimTime~fromMilliseconds(1)))
r = circuit~add(.Resistor~new('R1', 1000))
c = circuit~add(.Capacitor~new('C1', 0.000001))
circuit~connect('VCC', .array~of(v~positive, r~pin('A')))
circuit~connect('RC', .array~of(r~pin('B'), c~pin('A')))
circuit~connectGround(c~pin('B'))
circuit~connectGround(v~negative)
run = circuit~simulateTransient(clock, .SimTime~fromMilliseconds(6), .SimTime~fromMicroseconds(10))
say 't=2 ms:' run~voltageAt('RC', .SimTime~fromMilliseconds(2)) 'V'
say 't=6 ms:' run~voltageAt('RC', .SimTime~fromMilliseconds(6)) 'V'
::requires 'RexxTronicsTransient.cls'
