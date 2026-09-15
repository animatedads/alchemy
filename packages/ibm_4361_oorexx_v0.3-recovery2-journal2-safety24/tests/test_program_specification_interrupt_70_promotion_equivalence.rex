/* Safety23: live STE invalid-R1 classifier -> rewind -> remove -> permanent. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'SPEC70-PROMOTION-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
classifier="numeric digits 30; use strict arg raw; if raw~length<4 then return .false; op=raw~left(2)~translate; r1=x2d(raw~substr(3,1)); if op='5D' then return r1//2=1; if op='70' then return r1<>0 & r1<>2 & r1<>4 & r1<>6; return .false"
call truth m~executor~installLiveMethod('architecturalSpecificationException',classifier),'install live classifier'
session=.IBM4361JournalSession~new(m)
session~beginInstruction
st=m~executor~step
call eq 'OK',st,'live status'
liveOld=m~storage~fetchHex(x2d('28'),8); livePSW=m~cpu~psw~rawHex; liveIC=m~cpu~instructionCount
session~abortInstruction
call eq '0004000190000082',m~cpu~psw~rawHex,'rewind PSW'
call eq '0000000000000000',m~storage~fetchHex(x2d('28'),8),'rewind old PSW'
session~beginInstruction
call truth m~executor~removeLiveMethod('architecturalSpecificationException'),'remove live classifier'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'withdrawal rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('120'),2),'withdrawal rewind RAM'
st=m~executor~step
call eq 'OK',st,'permanent status'
call eq liveOld,m~storage~fetchHex(x2d('28'),8),'old PSW equivalence'
call eq livePSW,m~cpu~psw~rawHex,'new PSW equivalence'
call eq liveIC,m~cpu~instructionCount,'IC equivalence'
call eq '0004000690000086',liveOld,'recorded MVT old PSW'
call eq '00040000000002CA',livePSW,'recorded MVT new PSW'
call eq 0,m~executor~hasMethod('OP70'),'no OP70'
say 'PASS test_program_specification_interrupt_70_promotion_equivalence'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('0004000190000082')
  cs=m~cpu~state; cs['instructionCount']=539172; m~cpu~restoreState(cs)
  m~storage~storeHex(x2d('82'),'70E00000')
  m~storage~storeHex(x2d('68'),'00040000000002CA')
  m~storage~storeHex(x2d('28'),'0000000000000000')
  m~storage~storeHex(0,'A1B2C3D4')
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
