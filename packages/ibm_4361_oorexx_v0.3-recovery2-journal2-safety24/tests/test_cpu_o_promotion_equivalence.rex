/* Safety12 exact frontier candidate -> permanent O equivalence. */
numeric digits 30
storage=.IBM370JournaledStorage~new(262144,2048,'O-PROMOTION-RAM')
m=.IBM4361Machine~new(262144,storage); m~powerOn
call resetState
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); v=c2d(bitor(d2c(cpu~gprFast(f[1]),4),x2c(storage~fetchHex(ea,4)))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+4"
call truth m~executor~installLiveMethod('OP56',source),'install'
session=.IBM4361JournalSession~new(m)
session~beginInstruction; st=m~executor~step; call eq 'OK',st,'live status'; liveR=d2x(m~cpu~gpr(1),8); liveCC=m~cpu~psw~conditionCode; liveIA=d2x(m~cpu~psw~instructionAddress,6); liveMem=m~storage~fetchHex(x2d('35EDC'),4); session~abortInstruction
call eq '00035EC8',d2x(m~cpu~gpr(1),8),'rewind r1'; call eq '0146FC',d2x(m~cpu~psw~instructionAddress,6),'rewind ia'
session~beginInstruction; call truth m~executor~removeLiveMethod('OP56'),'remove'; m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A'); session~abortInstruction
call eq '000000FC',d2x(m~cpu~gpr(5),8),'rewind r5 historical'; call eq '0000',m~storage~fetchHex(x2d('120'),2),'rewind ram'
st=m~executor~step; call eq 'OK',st,'permanent status'; call eq liveR,d2x(m~cpu~gpr(1),8),'r equivalence'; call eq liveCC,m~cpu~psw~conditionCode,'cc equivalence'; call eq liveIA,d2x(m~cpu~psw~instructionAddress,6),'ia equivalence'; call eq liveMem,m~storage~fetchHex(x2d('35EDC'),4),'mem equivalence'; call eq 'FC035EC8',liveR,'expected result'; call eq 1,liveCC,'expected cc'; call eq '014700',liveIA,'expected ia'
say 'PASS test_cpu_o_promotion_equivalence'; exit 0
resetState: procedure expose m
 m~cpu~loadIPLPSW('FF040000800146FC'); m~storage~storeHex(x2d('146FC'),'561C0004'); m~cpu~setGpr(1,x2d('00035EC8')); m~cpu~setGpr(5,x2d('000000FC')); m~cpu~setGpr(12,x2d('00035ED8')); m~storage~storeHex(x2d('35EDC'),'FC000000')
return
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg x,l; if \x then do; say 'FAIL' l; exit 1; end; return
::requires 'IBM4361Journal.cls'
