numeric digits 50
p = .Maxitronix500Project007~new
s = p~solveDC
say p~kitId 'project' p~projectNumber':' p~title
say 'LED voltage:' p~led~voltageDrop
say 'LED current:' p~led~current
say 'LED lit:' p~led~lit
say 'nonlinear iterations:' s~iterations
::requires 'RexxTronicsKits.cls'
