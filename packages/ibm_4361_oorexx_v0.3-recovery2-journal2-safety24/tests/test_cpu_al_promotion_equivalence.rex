/* Safety11: successful live AL candidate and permanent OP5E must agree from
 * the identical recorded MVT frontier microstate. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'AL-PROMOTION-RAM')
m=.IBM4361Machine~new(131072,storage)
m~powerOn
call resetState
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); a=cpu~gprFast(f[1]); b=x2d(storage~fetchHex(ea,4)); exact=a+b; carry=(exact>=4294967296); v=exact//4294967296; cpu~setGprFast(f[1],v); if carry then do; if v=0 then cc=2; else cc=3; end; else do; if v=0 then cc=0; else cc=1; end; cpu~psw~setConditionCode(cc); return ia+4"
call truth m~executor~installLiveMethod('OP5E',source),'install live AL'
session=.IBM4361JournalSession~new(m)

session~beginInstruction
st=m~executor~step
call eq 'OK',st,'live status'
liveR6=d2x(m~cpu~gpr(6),8); liveCC=m~cpu~psw~conditionCode; liveIA=d2x(m~cpu~psw~instructionAddress,6); liveMem=m~storage~fetchHex(x2d('15D50'),4)
session~abortInstruction
call eq '80016A60',d2x(m~cpu~gpr(6),8),'rewind R6'
call eq '0154D0',d2x(m~cpu~psw~instructionAddress,6),'rewind IA'

/* Withdrawal is also outside machine history. */
session~beginInstruction
call truth m~executor~removeLiveMethod('OP5E'),'remove live AL'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'withdrawal rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('120'),2),'withdrawal rewind RAM'

st=m~executor~step
call eq 'OK',st,'permanent status'
call eq liveR6,d2x(m~cpu~gpr(6),8),'R6 equivalence'
call eq liveCC,m~cpu~psw~conditionCode,'CC equivalence'
call eq liveIA,d2x(m~cpu~psw~instructionAddress,6),'IA equivalence'
call eq liveMem,m~storage~fetchHex(x2d('15D50'),4),'storage equivalence'
call eq 'C0016A60',liveR6,'recorded MVT result'
call eq 1,liveCC,'recorded MVT cc'
call eq '0154D4',liveIA,'recorded MVT next IA'

say 'PASS test_cpu_al_promotion_equivalence'
exit 0

resetState: procedure expose m
  m~cpu~loadIPLPSW('00040000900154D0')
  m~storage~storeHex(x2d('154D0'),'5E60C888')
  m~cpu~setGpr(6,x2d('80016A60'))
  m~cpu~setGpr(12,x2d('0154C8'))
  m~storage~storeHex(x2d('15D50'),'40000000')
return

eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361Journal.cls'
