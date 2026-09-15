/* Safety24: permanent EX target specification exception uses EX IA/ILC. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'S24-EX-PERM-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
st=m~executor~step
call eq 'OK',st,'permanent EX target specification interruption'
call eq '00040006800004BA',m~storage~fetchHex(x2d('28'),8),'program-old PSW identifies EX'
call eq '00040000000002CA',m~cpu~psw~rawHex,'program-new PSW'
call eq 539206,m~cpu~instructionCount,'EX count once'
call eq 0,m~executor~hasMethod('OP70'),'no OP70'
call eq '440004F4->70E005C84780',m~executor~lastInstruction,'target evidence'
say 'PASS test_program_specification_interrupt_ex_target_permanent'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('00040000800004B6')
  cs=m~cpu~state; cs['instructionCount']=539205; m~cpu~restoreState(cs)
  m~storage~storeHex(x2d('4B6'),'440004F4')
  m~storage~storeHex(x2d('4F4'),'70E005C84780')
  m~storage~storeHex(x2d('68'),'00040000000002CA')
  m~storage~storeHex(x2d('28'),'0000000000000000')
return
eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
::requires 'IBM4361Journal.cls'
