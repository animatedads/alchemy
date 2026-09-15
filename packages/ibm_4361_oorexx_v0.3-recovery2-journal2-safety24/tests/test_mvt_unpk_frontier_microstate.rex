numeric digits 30
/* Exact architectural microstate extracted from the real-MVT F3 journal trial.
 * This is not a replacement for the full guest trajectory: it locks the
 * permanent OPF3 implementation to the same instruction/operand/PSW evidence
 * used by the successful rewind/retry experiment. */
m=.IBM4361Machine~new(16777216)
m~powerOn
m~cpu~loadIPLPSW('00040000B0FF71B4')
m~cpu~setGpr(13,x2d('FFCDF9'))
cs=m~cpu~state
cs['instructionCount']=511764
m~cpu~restoreState(cs)
m~storage~storeHex(x2d('FF71B4'),'F332D643D67C')
m~storage~storeHex(x2d('FFD43C'),'F0F0F0F0')
m~storage~storeHex(x2d('FFD475'),'00013C')

if m~storage~fetchHex(x2d('FFD43C'),4) \== 'F0F0F0F0' then do; say 'FAIL pre destination'; exit 1; end
if m~storage~fetchHex(x2d('FFD475'),3) \== '00013C' then do; say 'FAIL pre source'; exit 1; end
if m~cpu~psw~conditionCode \== 3 then do; say 'FAIL pre CC' m~cpu~psw~conditionCode; exit 1; end
if m~cpu~instructionCount \== 511764 then do; say 'FAIL pre IC' m~cpu~instructionCount; exit 1; end

st=m~executor~step
if st \== 'OK' then do; say 'FAIL status' st; exit 1; end
if m~storage~fetchHex(x2d('FFD43C'),4) \== 'F0F0F1C3' then do; say 'FAIL destination' m~storage~fetchHex(x2d('FFD43C'),4); exit 1; end
if m~cpu~psw~conditionCode \== 3 then do; say 'FAIL CC changed' m~cpu~psw~conditionCode; exit 1; end
if m~cpu~psw~instructionAddress \== x2d('FF71BA') then do; say 'FAIL IA' d2x(m~cpu~psw~instructionAddress,6); exit 1; end
if m~cpu~instructionCount \== 511765 then do; say 'FAIL IC' m~cpu~instructionCount; exit 1; end

say 'PASS test_mvt_unpk_frontier_microstate'
exit 0

::requires 'IBM4361.cls'
