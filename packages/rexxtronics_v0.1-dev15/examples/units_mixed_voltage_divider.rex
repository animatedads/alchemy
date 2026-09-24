numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', .Units~q(9000, .Units~millivolt)))
r1 = c~add(.Resistor~new('R1', .Units~q(1, .Units~kiloohm)))
r2 = c~add(.Resistor~new('R2', .Units~q(0.002, .Units~megaohm)))

c~connect('VCC', .array~of(v~positive, r1~pin('A')))
c~connect('MID', .array~of(r1~pin('B'), r2~pin('A')))
c~connectGround(r2~pin('B'))
c~connectGround(v~negative)

solution = c~solveDC
say 'Supply:' solution~voltageQuantity('VCC', .Units~millivolt)
say 'Middle:' solution~voltageQuantity('MID', .Units~volt)
say 'Current:' solution~currentQuantity('R1', .Units~milliampere)
say 'R1:' r1~resistance~as(.Units~kiloohm)
say 'R2:' r2~resistance~as(.Units~kiloohm)

::requires 'RexxTronicsDC.cls'
