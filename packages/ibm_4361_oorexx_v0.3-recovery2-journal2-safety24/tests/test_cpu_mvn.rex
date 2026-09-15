/* Safety20 permanent D1 / MVN semantics. */
numeric digits 30
m=.IBM4361Machine~new(16777216); m~powerOn

/* Exact recorded MVT microstate: 10 with source B8 becomes 18; CC unchanged. */
m~cpu~loadIPLPSW('000400008000047C'); m~storage~storeHex(x2d('47C'),'D10004E705D1'); m~storage~storeHex(x2d('4E7'),'10'); m~storage~storeHex(x2d('5D1'),'B8'); m~cpu~psw~setConditionCode(0)
st=m~executor~step; call eq 'OK',st,'mvt status'; call eq '18',m~storage~fetchHex(x2d('4E7'),1),'mvt destination'; call eq 'B8',m~storage~fetchHex(x2d('5D1'),1),'mvt source'; call eq 0,m~cpu~psw~conditionCode,'mvt cc'; call eq '000482',d2x(m~cpu~psw~instructionAddress,6),'mvt ia'

/* Disjoint four-byte move: preserve zones, copy numeric nibbles, source intact. */
m~cpu~loadIPLPSW('00000000C0000100'); m~storage~storeHex(x2d('100'),'D10303000400'); m~storage~storeHex(x2d('300'),'F1C2D3A4'); m~storage~storeHex(x2d('400'),'091A2B3C'); m~cpu~psw~setConditionCode(3)
st=m~executor~step; call eq 'OK',st,'disjoint status'; call eq 'F9CADBAC',m~storage~fetchHex(x2d('300'),4),'disjoint result'; call eq '091A2B3C',m~storage~fetchHex(x2d('400'),4),'disjoint source'; call eq 3,m~cpu~psw~conditionCode,'disjoint cc'

/* Destructive overlap: destination begins one byte after source.  Sequential
 * MVN re-reads each source byte after earlier destination modification. */
m~cpu~loadIPLPSW('0000000080000100'); m~storage~storeHex(x2d('100'),'D10303010300'); m~storage~storeHex(x2d('300'),'A1B2C3D4E5'); m~cpu~psw~setConditionCode(2)
st=m~executor~step; call eq 'OK',st,'overlap status'; call eq 'A1B1C1D1E1',m~storage~fetchHex(x2d('300'),5),'overlap sequential'; call eq 2,m~cpu~psw~conditionCode,'overlap cc'

/* 24-bit wrap: destination FFFFFE, FFFFFF, 000000, 000001. */
m~cpu~loadIPLPSW('0000000040000100'); m~storage~storeHex(x2d('100'),'D103FFFE0200'); m~cpu~setGpr(15,x2d('00FFF000')); m~storage~storeHex(x2d('FFFFFE'),'A1B2'); m~storage~storeHex(0,'C3D4'); m~storage~storeHex(x2d('200'),'091A2B3C'); m~cpu~psw~setConditionCode(1)
st=m~executor~step; call eq 'OK',st,'wrap status'; call eq 'A9BA',m~storage~fetchHex(x2d('FFFFFE'),2),'wrap high'; call eq 'CBDC',m~storage~fetchHex(0,2),'wrap low'; call eq 1,m~cpu~psw~conditionCode,'wrap cc'

say 'PASS test_cpu_mvn'; exit 0
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
::requires 'IBM4361.cls'
