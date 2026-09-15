/* Safety13 live OPD4 candidate. */
numeric digits 30
m=.IBM4361Machine~new(16777216); m~powerOn
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); nz=0; do n=0 to f[1]-1; d=(a1+n)//16777216; s=(a2+n)//16777216; v=c2x(bitand(x2c(storage~fetchHex(d,1)),x2c(storage~fetchHex(s,1)))); storage~storeHex(d,v); if v<>'00' then nz=1; end; cpu~psw~setConditionCode(nz); return ia+6"
call truth m~executor~installLiveMethod('OPD4',source),'install'
m~cpu~loadIPLPSW('0000000000000100'); m~storage~storeHex(x2d('100'),'D40303010300'); m~storage~storeHex(x2d('300'),'F00FAA55FF'); st=m~executor~step
call eq 'OK',st,'status'; call eq 'F000000000',m~storage~fetchHex(x2d('300'),5),'overlap'; call eq 0,m~cpu~psw~conditionCode,'cc'
say 'PASS test_cpu_nc_live_trial'; exit 0
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg x,l; if \x then do; say 'FAIL' l; exit 1; end; return
::requires 'IBM4361.cls'
