numeric digits 50
p = .Maxitronix500Project014PNP~new
p~solveDC
say 'PNP key released: state=' p~transistor~state 'LED=' p~led~lit
p~press~solveDC
say 'PNP key pressed:  state=' p~transistor~state 'LED=' p~led~lit 'Ic(mA)=' p~transistor~collectorCurrent~in(.Units~milliampere)

n = .Maxitronix500Project014NPN~new
n~solveDC
say 'NPN key released: state=' n~transistor~state 'LED=' n~led~lit
n~press~solveDC
say 'NPN key pressed:  state=' n~transistor~state 'LED=' n~led~lit 'Ic(mA)=' n~transistor~collectorCurrent~in(.Units~milliampere)
::requires 'RexxTronicsKits.cls'
