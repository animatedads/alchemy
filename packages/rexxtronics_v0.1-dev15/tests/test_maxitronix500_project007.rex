/* Qualification: first source-backed 500-in-1 project fixture. */
numeric digits 50
p = .Maxitronix500Project007~new
s = p~solveDC
if p~projectNumber <> 7 then do; say 'FAIL: project number'; exit 1; end
if \p~led~lit then do; say 'FAIL: Project 7 LED should light with S1 closed'; exit 1; end
if s~current(p~led) < 0.004 | s~current(p~led) > 0.005 then do
  say 'FAIL: Project 7 LED current' s~current(p~led); exit 1
end
p~release
s2 = p~solveDC
if p~led~lit then do; say 'FAIL: Project 7 LED should be off with S1 open'; exit 1; end
say 'REXX-TRONICS MAXITRONIX 500 PROJECT 007: OK'
say 'closed LED current mA:' s~current(p~led) * 1000
say 'open LED current uA:' s2~current(p~led) * 1000000
exit 0
::requires 'RexxTronicsKits.cls'
