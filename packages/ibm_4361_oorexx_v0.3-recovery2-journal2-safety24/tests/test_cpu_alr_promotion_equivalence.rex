/* Safety15: successful live ALR candidate and permanent OP1E must agree from
 * the identical recorded MVT frontier microstate. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'ALR-PROMOTION-RAM')
m=.IBM4361Machine~new(131072,storage)
m~powerOn
call resetState
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; f=self~rr(i); a=cpu~gprFast(f[1]); b=cpu~gprFast(f[2]); exact=a+b; carry=(exact>=4294967296); v=exact//4294967296; cpu~setGprFast(f[1],v); if carry then do; if v=0 then cc=2; else cc=3; end; else do; if v=0 then cc=0; else cc=1; end; cpu~psw~setConditionCode(cc); return ia+2"
call truth m~executor~installLiveMethod('OP1E',source),'install live ALR'
session=.IBM4361JournalSession~new(m)

session~beginInstruction
st=m~executor~step
call eq 'OK',st,'live status'
liveR10=d2x(m~cpu~gpr(10),8); liveCC=m~cpu~psw~conditionCode; liveIA=d2x(m~cpu~psw~instructionAddress,6)
session~abortInstruction
call eq '20000000',d2x(m~cpu~gpr(10),8),'rewind R10'
call eq '01A482',d2x(m~cpu~psw~instructionAddress,6),'rewind IA'

session~beginInstruction
call truth m~executor~removeLiveMethod('OP1E'),'remove live ALR'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'withdrawal rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('120'),2),'withdrawal rewind RAM'

st=m~executor~step
call eq 'OK',st,'permanent status'
call eq liveR10,d2x(m~cpu~gpr(10),8),'R10 equivalence'
call eq liveCC,m~cpu~psw~conditionCode,'CC equivalence'
call eq liveIA,d2x(m~cpu~psw~instructionAddress,6),'IA equivalence'
call eq '60000002',liveR10,'recorded MVT result'
call eq 1,liveCC,'recorded MVT cc'
call eq '01A484',liveIA,'recorded MVT next IA'

say 'PASS test_cpu_alr_promotion_equivalence'
exit 0

resetState: procedure expose m
  m~cpu~loadIPLPSW('000400009001A482')
  m~storage~storeHex(x2d('1A482'),'1EAB')
  m~cpu~setGpr(10,x2d('20000000'))
  m~cpu~setGpr(11,x2d('40000002'))
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
