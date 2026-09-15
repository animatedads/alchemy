/* Safety24: reproduce pre-promotion EX target retry with live method lifetime. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'S24-EX-LIVE-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
oldStep=readText('evidence/safety24_step_pre_promotion.rexsrc')
newStep=readText('evidence/safety24_step_candidate.rexsrc')
call truth m~executor~installLiveMethod('step',oldStep),'install pre-Safety24 step'
session=.IBM4361JournalSession~new(m); session~beginInstruction
first=m~executor~step
call eq 'UNSUPPORTED',first,'pre-Safety24 target unsupported'
call eq 'UNSUPPORTED_EX_TARGET',m~executor~lastStatus,'pre-Safety24 status'
call eq '00040000800004B6',m~cpu~psw~rawHex,'first atomic PSW'
call eq 539205,m~cpu~instructionCount,'first atomic IC'
call truth m~executor~installLiveMethod('step',newStep),'replace with Safety24 candidate'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('1234'),2),'rewind RAM'
call eq '0004B6',d2x(m~cpu~psw~instructionAddress,6),'rewind IA'
call eq 539205,m~cpu~instructionCount,'rewind IC'
session~beginInstruction; st=m~executor~step; session~commitInstruction
call eq 'OK',st,'live EX target specification retry'
call eq '00040006800004BA',m~storage~fetchHex(x2d('28'),8),'program-old PSW'
call eq '00040000000002CA',m~cpu~psw~rawHex,'program-new PSW'
call eq 539206,m~cpu~instructionCount,'EX count once'
call eq 0,m~executor~hasMethod('OP70'),'no OP70'
say 'PASS test_program_specification_interrupt_ex_target_live_trial'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('00040000800004B6')
  cs=m~cpu~state; cs['instructionCount']=539205; m~cpu~restoreState(cs)
  m~storage~storeHex(x2d('4B6'),'440004F4')
  m~storage~storeHex(x2d('4F4'),'70E005C84780')
  m~storage~storeHex(x2d('68'),'00040000000002CA')
  m~storage~storeHex(x2d('28'),'0000000000000000')
return
readText: procedure
  use arg path
  text=''
  do while lines(path)>0; text=text||linein(path)||';'; end
  call lineout path
  return text
eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361Journal.cls'
