/* Safety13 exact MVT NC live candidate -> permanent equivalence. */
numeric digits 30
storage=.IBM370JournaledStorage~new(16777216,2048,'NC-PROMOTION-RAM'); m=.IBM4361Machine~new(16777216,storage); m~powerOn
call resetState
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); nz=0; do n=0 to f[1]-1; d=(a1+n)//16777216; s=(a2+n)//16777216; v=c2x(bitand(x2c(storage~fetchHex(d,1)),x2c(storage~fetchHex(s,1)))); storage~storeHex(d,v); if v<>'00' then nz=1; end; cpu~psw~setConditionCode(nz); return ia+6"
call truth m~executor~installLiveMethod('OPD4',source),'install'; session=.IBM4361JournalSession~new(m)
session~beginInstruction; st=m~executor~step; call eq 'OK',st,'live status'; liveCC=m~cpu~psw~conditionCode; liveIA=d2x(m~cpu~psw~instructionAddress,6); liveMem=m~storage~fetchHex(x2d('B0A0'),4); session~abortInstruction
call eq '00660C',d2x(m~cpu~psw~instructionAddress,6),'rewind ia'; call eq 1,m~cpu~psw~conditionCode,'rewind cc'
session~beginInstruction; call truth m~executor~removeLiveMethod('OPD4'),'remove'; m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A'); session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'rewind r5'; call eq '0000',m~storage~fetchHex(x2d('1234'),2),'rewind ram'
st=m~executor~step; call eq 'OK',st,'permanent status'; call eq liveCC,m~cpu~psw~conditionCode,'cc equivalence'; call eq liveIA,d2x(m~cpu~psw~instructionAddress,6),'ia equivalence'; call eq liveMem,m~storage~fetchHex(x2d('B0A0'),4),'mem equivalence'; call eq 0,liveCC,'expected cc'; call eq '006612',liveIA,'expected ia'; call eq '00000000',liveMem,'expected mem'
say 'PASS test_cpu_nc_promotion_equivalence'; exit 0
resetState: procedure expose m
 m~cpu~loadIPLPSW('0004000A6000660C'); m~storage~storeHex(x2d('660C'),'D403A0A0A0A0'); m~cpu~setGpr(10,x2d('0000B000')); m~storage~storeHex(x2d('B0A0'),'00000000'); m~cpu~psw~setConditionCode(1)
return
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg x,l; if \x then do; say 'FAIL' l; exit 1; end; return
::requires 'IBM4361Journal.cls'
