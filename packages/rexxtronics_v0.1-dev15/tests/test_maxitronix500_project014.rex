/* Source-backed qualification of Maxitronix 500-in-1 Project 14, both
 * transistor-polarity schematics.  Exact BJT characteristics are not claimed;
 * the fixture qualifies the manual's topology and qualitative stated result:
 * pressing S1 supplies base current and lights LED1.
 */
numeric digits 50

p = .Maxitronix500Project014PNP~new
openP = p~solveDC
if p~transistor~state <> 'CUTOFF' then do; say 'FAIL: Project 14 PNP open state' p~transistor~state; exit 1; end
if p~led~lit then do; say 'FAIL: Project 14 PNP LED lit with key released'; exit 1; end
p~press
closedP = p~solveDC
if p~transistor~state = 'CUTOFF' then do; say 'FAIL: Project 14 PNP did not conduct'; exit 1; end
if \p~led~lit then do; say 'FAIL: Project 14 PNP LED did not light'; exit 1; end
if abs(p~transistor~collectorCurrent~in(.Units~ampere)) <= abs(p~transistor~baseCurrent~in(.Units~ampere)) then do
  say 'FAIL: Project 14 PNP did not demonstrate current gain'; exit 1
end

n = .Maxitronix500Project014NPN~new
openN = n~solveDC
if n~transistor~state <> 'CUTOFF' then do; say 'FAIL: Project 14 NPN open state' n~transistor~state; exit 1; end
if n~led~lit then do; say 'FAIL: Project 14 NPN LED lit with key released'; exit 1; end
n~press
closedN = n~solveDC
if n~transistor~state = 'CUTOFF' then do; say 'FAIL: Project 14 NPN did not conduct'; exit 1; end
if \n~led~lit then do; say 'FAIL: Project 14 NPN LED did not light'; exit 1; end
if abs(n~transistor~collectorCurrent~in(.Units~ampere)) <= abs(n~transistor~baseCurrent~in(.Units~ampere)) then do
  say 'FAIL: Project 14 NPN did not demonstrate current gain'; exit 1
end

say 'REXX-TRONICS MAXITRONIX 500 PROJECT 014: OK'
say 'PNP closed state:' p~transistor~state
say 'PNP LED current mA:' p~led~current~in(.Units~milliampere)
say 'NPN closed state:' n~transistor~state
say 'NPN LED current mA:' n~led~current~in(.Units~milliampere)
exit 0

::requires 'RexxTronicsKits.cls'
