numeric digits 50

c = .Circuit~new
source = c~add(.DCVoltageSource~new('BAT1', 9))
rTop = c~add(.Resistor~new('R1', 1000))
rBottom = c~add(.Resistor~new('R2', 2000))

c~connect('VCC', .array~of(source~positive, rTop~pin('A')))
c~connect('SENSE', .array~of(rTop~pin('B'), rBottom~pin('A')))
c~connectGround(rBottom~pin('B'))
c~connectGround(source~negative)

solution = c~solveDC
say 'VCC:' solution~voltage('VCC') 'V'
say 'SENSE:' solution~voltage('SENSE') 'V'
say 'R1 current:' solution~current(rTop) 'A'
say 'R2 current:' solution~current(rBottom) 'A'
say 'R1 power:' solution~power(rTop) 'W'
say 'R2 power:' solution~power(rBottom) 'W'

::requires 'RexxTronicsDC.cls'
