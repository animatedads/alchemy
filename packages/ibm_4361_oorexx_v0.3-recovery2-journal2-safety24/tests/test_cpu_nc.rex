/* Safety13 permanent NC / And Character semantics. */
numeric digits 30
m=.IBM4361Machine~new(16777216); m~powerOn
/* exact MVT self-NC: four zero bytes, CC1 -> CC0 */
m~cpu~loadIPLPSW('0004000040000100'); m~storage~storeHex(x2d('100'),'D403A0A0A0A0'); m~cpu~setGpr(10,x2d('0000B000')); m~storage~storeHex(x2d('B0A0'),'00000000'); m~cpu~psw~setConditionCode(1)
st=m~executor~step; call eq 'OK',st,'mvt status'; call eq '00000000',m~storage~fetchHex(x2d('B0A0'),4),'mvt data'; call eq 0,m~cpu~psw~conditionCode,'mvt cc'; call eq '000106',d2x(m~cpu~psw~instructionAddress,6),'mvt ia'
/* disjoint non-zero */
m~cpu~loadIPLPSW('0000000000000100'); m~storage~storeHex(x2d('100'),'D40303000400'); m~storage~storeHex(x2d('300'),'FF0FF00F'); m~storage~storeHex(x2d('400'),'0FF0FF0F'); st=m~executor~step
call eq 'OK',st,'disjoint status'; call eq '0F00F00F',m~storage~fetchHex(x2d('300'),4),'disjoint result'; call eq 1,m~cpu~psw~conditionCode,'disjoint cc'; call eq '0FF0FF0F',m~storage~fetchHex(x2d('400'),4),'source unchanged'
/* destructive overlap: destination begins one byte after source.  Correct
 * byte-sequential NC cascades zeroes; snapshot semantics would not. */
m~cpu~loadIPLPSW('0000000000000100'); m~storage~storeHex(x2d('100'),'D40303010300'); m~storage~storeHex(x2d('300'),'F00FAA55FF'); st=m~executor~step
call eq 'OK',st,'overlap status'; call eq 'F000000000',m~storage~fetchHex(x2d('300'),5),'overlap sequential'; call eq 0,m~cpu~psw~conditionCode,'overlap cc'
/* 24-bit wrap: destination FFFFFE..000001 */
m~cpu~loadIPLPSW('0000000000000100'); m~storage~storeHex(x2d('100'),'D403FFFE0200'); m~cpu~setGpr(15,x2d('00FFF000')); m~storage~storeHex(x2d('FFFFFE'),'FF0F'); m~storage~storeHex(0,'F00F'); m~storage~storeHex(x2d('200'),'0FF0FFFF'); st=m~executor~step
call eq 'OK',st,'wrap status'; call eq '0F00',m~storage~fetchHex(x2d('FFFFFE'),2),'wrap high'; call eq 'F00F',m~storage~fetchHex(0,2),'wrap low'; call eq 1,m~cpu~psw~conditionCode,'wrap cc'
say 'PASS test_cpu_nc'; exit 0
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
::requires 'IBM4361.cls'
