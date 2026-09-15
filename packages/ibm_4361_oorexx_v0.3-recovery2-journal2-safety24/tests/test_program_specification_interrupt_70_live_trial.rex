/* Safety23 exact X'70' @ X'82': pre-promotion unsupported -> live spec retry. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'SPEC70-LIVE-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
oldClassifier="numeric digits 30; use strict arg raw; if raw~length<4 then return .false; op=raw~left(2)~translate; r1=x2d(raw~substr(3,1)); if op='5D' then return r1//2=1; return .false"
newClassifier="numeric digits 30; use strict arg raw; if raw~length<4 then return .false; op=raw~left(2)~translate; r1=x2d(raw~substr(3,1)); if op='5D' then return r1//2=1; if op='70' then return r1<>0 & r1<>2 & r1<>4 & r1<>6; return .false"
call truth m~executor~installLiveMethod('architecturalSpecificationException',oldClassifier),'install pre-Safety23 classifier'
session=.IBM4361JournalSession~new(m)
session~beginInstruction
first=m~executor~step
call eq 'UNSUPPORTED',first,'pre-promotion 70 unsupported'
call eq '0004000190000082',m~cpu~psw~rawHex,'unsupported atomic PSW'
call eq 539172,m~cpu~instructionCount,'unsupported atomic IC'
call truth m~executor~installLiveMethod('architecturalSpecificationException',newClassifier),'install Safety23 classifier'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('120'),2),'rewind RAM'
call eq '000082',d2x(m~cpu~psw~instructionAddress,6),'rewind IA'
call eq 539172,m~cpu~instructionCount,'rewind IC'
session~beginInstruction
st=m~executor~step
session~commitInstruction
call eq 'OK',st,'specification retry'
call eq '0004000690000086',m~storage~fetchHex(x2d('28'),8),'program-old PSW'
call eq '00040000000002CA',m~cpu~psw~rawHex,'program-new PSW'
call eq 539173,m~cpu~instructionCount,'instruction count'
call eq 'A1B2C3D4',m~storage~fetchHex(0,4),'store suppressed'
call eq 0,m~executor~hasMethod('OP70'),'no OP70'
say 'PASS test_program_specification_interrupt_70_live_trial'
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
