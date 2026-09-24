/* Qualification: nonlinear LED state follows a simulation-time source step. */
numeric digits 50
clock = .SimulationClock~new
c = .Circuit~new
v = c~add(.StepVoltageSource~new('V1', '0 V', '3 V', '1 ms'))
r = c~add(.Resistor~new('R1', '270 Ohm'))
led = c~add(.LED~new('LED1'))
c~connectGround(v~negative)
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('LED', .array~of(r~pin('B'), led~anode))
c~connectGround(led~cathode)
run = c~simulateTransient(clock, '3 ms', '0.1 ms')
if run~voltageAt('LED','0.5 ms') > 0.01 then do; say 'FAIL: LED node before step'; exit 1; end
if run~voltageAt('LED','2 ms') < 1.7 then do; say 'FAIL: LED node after step'; exit 1; end
if \led~lit then do; say 'FAIL: LED should be lit after transient'; exit 1; end
say 'REXX-TRONICS LED TRANSIENT: OK'
say 'LED at 2 ms:' run~voltageAt('LED','2 ms') 'V'
say 'LED current mA:' led~current~in(.Units~milliampere)
exit 0
::requires 'RexxTronicsTime.cls'
::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsTransient.cls'
