/* Source-backed qualification of Maxitronix 500-in-1 Project 15. */
numeric digits 50
p = .Maxitronix500Project015~new
openResult = p~solveDC
if p~transistor~state <> 'CUTOFF' then do; say 'FAIL: Project 15 transistor should be cutoff'; exit 1; end
if p~display~litSegments~items <> 0 then do; say 'FAIL: Project 15 display should be dark'; exit 1; end

p~press
closedResult = p~solveDC
if p~transistor~state <> 'SATURATED' then do; say 'FAIL: Project 15 transistor should saturate' p~transistor~state; exit 1; end
if p~display~displayedDigit <> 8 then do; say 'FAIL: Project 15 should display 8, got' p~display~displayedDigit; exit 1; end
if p~display~litSegments~items <> 7 then do; say 'FAIL: Project 15 should light all seven segments'; exit 1; end

say 'REXX-TRONICS MAXITRONIX 500 PROJECT 015: OK'
say 'closed transistor state:' p~transistor~state
say 'displayed digit:' p~display~displayedDigit
say 'segment A current mA:' p~display~segmentCurrent('A')~in(.Units~milliampere)
exit 0
::requires 'RexxTronicsKits.cls'
