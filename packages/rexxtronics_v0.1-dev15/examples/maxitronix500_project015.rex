numeric digits 50
p = .Maxitronix500Project015~new
p~solveDC
say 'released: Q1=' p~transistor~state 'lit segments=' p~display~litSegments~items
p~press~solveDC
say 'pressed:  Q1=' p~transistor~state 'digit=' p~display~displayedDigit
say 'segment A current=' p~display~segmentCurrent('A')~in(.Units~milliampere) 'mA'
::requires 'RexxTronicsKits.cls'
