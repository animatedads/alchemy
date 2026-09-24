numeric digits 50
points = .array~new
points~append(.LightResistancePoint~new(.Units~q(0,.Units~lux), '1 Mohm'))
points~append(.LightResistancePoint~new(.Units~q(100,.Units~lux), '10 kohm'))
points~append(.LightResistancePoint~new(.Units~q(1000,.Units~lux), '1 kohm'))
curve = .LightResistanceCurve~new(points)

clock = .SimulationClock~new
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1','5 V'))
r = c~add(.Resistor~new('R1','10 kohm'))
ldr = c~add(.PhotoResistor~new('LDR1',curve,.Units~q(100,.Units~lux)))
c~connect('VCC',.array~of(v~positive,r~pin('A')))
c~connect('SENSE',.array~of(r~pin('B'),ldr~pin('A')))
c~connectGround(ldr~pin('B'))
c~connectGround(v~negative)

ldr~scheduleIlluminance(clock,'2 ms',.Units~q(1000,.Units~lux),'Physics mirror/prism path')
run = c~simulateTransient(clock,'4 ms','0.1 ms')
say 'SENSE at 1.9 ms:' run~voltageAtQuantity('SENSE','1.9 ms')~in(.Units~volt) 'V'
say 'SENSE at 2.1 ms:' run~voltageAtQuantity('SENSE','2.1 ms')~in(.Units~volt) 'V'
say 'accepted stimulus:' ldr~illuminance~in(.Units~lux) 'lx at' ldr~lastStimulusTime~in(.Units~millisecond) 'ms'

::requires 'RexxTronicsSensors.cls'
::requires 'RexxTronicsTransient.cls'
