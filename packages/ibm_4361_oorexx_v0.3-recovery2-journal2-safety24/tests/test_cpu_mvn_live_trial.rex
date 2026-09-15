/* Safety20 live D1 / MVN candidate, including destructive overlap. */
numeric digits 30
m=.IBM4361Machine~new(16777216); m~powerOn
source="expose storage; numeric digits 30; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); do n=0 to f[1]-1; d=(a1+n)//16777216; s=(a2+n)//16777216; db=storage~fetchHex(d,1); sb=storage~fetchHex(s,1); storage~storeHex(d,db~left(1)||sb~right(1)); end; return ia+6"
call truth m~executor~installLiveMethod('OPD1',source),'install'
m~cpu~loadIPLPSW('0000000080000100'); m~storage~storeHex(x2d('100'),'D10303010300'); m~storage~storeHex(x2d('300'),'A1B2C3D4E5'); m~cpu~psw~setConditionCode(2)
st=m~executor~step
call eq 'OK',st,'status'; call eq 'A1B1C1D1E1',m~storage~fetchHex(x2d('300'),5),'overlap'; call eq 2,m~cpu~psw~conditionCode,'cc'
say 'PASS test_cpu_mvn_live_trial'; exit 0
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg x,l; if \x then do; say 'FAIL' l; exit 1; end; return
::requires 'IBM4361.cls'
