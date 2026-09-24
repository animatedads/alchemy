numeric digits 50
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '5 V'))
rc = c~add(.Resistor~new('RC', '1 kOhm'))
rb = c~add(.Resistor~new('RB', '220 kOhm'))
q = c~add(.NPNTransistor~new('Q1', 100))
c~connectGround(v~negative)
c~connectGround(q~emitter)
c~connect('VCC', .array~of(v~positive, rc~pin('A'), rb~pin('A')))
c~connect('COLLECTOR', .array~of(rc~pin('B'), q~collector))
c~connect('BASE', .array~of(rb~pin('B'), q~base))
s = c~solveDC
say q~state
say 'Vb=' s~voltage('BASE') 'V'
say 'Vc=' s~voltage('COLLECTOR') 'V'
say 'Ib=' q~baseCurrent~in(.Units~microampere) 'uA'
say 'Ic=' q~collectorCurrent~in(.Units~milliampere) 'mA'
::requires 'RexxTronicsSemiconductors.cls'
