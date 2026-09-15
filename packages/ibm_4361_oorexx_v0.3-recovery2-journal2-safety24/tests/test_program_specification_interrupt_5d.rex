/* Safety19 permanent System/370 D odd-R1 specification exception. */
numeric digits 30
m=.IBM4361Machine~new(131072); m~powerOn
call resetState
call eq 0,m~executor~hasMethod('OP5D'),'no permanent OP5D'
st=m~executor~step
call eq 'OK',st,'specification status'
call eq '00040006A0000062',m~storage~fetchHex(x2d('28'),8),'program-old PSW'
call eq '00040000000002CA',m~cpu~psw~rawHex,'program-new PSW'
call eq '40016614',d2x(m~cpu~gpr(11),8),'R11 unchanged'
call eq '00000000',m~storage~fetchHex(x2d('1D8'),4),'divisor unchanged'

/* Even-R1 D is still a genuine implementation gap. */
m~cpu~loadIPLPSW('000400016000005E'); m~storage~storeHex(x2d('5E'),'5DA80004')
call eq 'UNSUPPORTED',m~executor~step,'even-R1 D remains unsupported'

/* Architectural validity check must win even if a future/live OP5D exists. */
call resetState
dummy="expose cpu; use strict arg i,ia,t=0; cpu~setGprFast(11,x2d('DEADBEEF')); return ia+4"
call truth m~executor~installLiveMethod('OP5D',dummy),'install dummy OP5D'
st=m~executor~step
call eq 'OK',st,'spec preflight before OP5D'
call eq '40016614',d2x(m~cpu~gpr(11),8),'dummy OP5D not executed'
call eq '00040006A0000062',m~storage~fetchHex(x2d('28'),8),'preflight old PSW'
call truth m~executor~removeLiveMethod('OP5D'),'remove dummy OP5D'

say 'PASS test_program_specification_interrupt_5d'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('000400016000005E')
  m~storage~storeHex(x2d('5E'),'5DB80004')
  m~storage~storeHex(x2d('68'),'00040000000002CA')
  m~storage~storeHex(x2d('28'),'0000000000000000')
  m~storage~storeHex(x2d('1D8'),'00000000')
  m~cpu~setGpr(8,x2d('000001D4')); m~cpu~setGpr(11,x2d('40016614'))
return
eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361.cls'
