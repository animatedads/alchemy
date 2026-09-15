/* Safety23 permanent System/370 STE invalid-R1 specification exception. */
numeric digits 30
m=.IBM4361Machine~new(131072); m~powerOn
call resetState
call eq 0,m~executor~hasMethod('OP70'),'no permanent OP70'
st=m~executor~step
call eq 'OK',st,'specification status'
call eq '0004000690000086',m~storage~fetchHex(x2d('28'),8),'program-old PSW'
call eq '00040000000002CA',m~cpu~psw~rawHex,'program-new PSW'
call eq 'A1B2C3D4',m~storage~fetchHex(0,4),'store operand suppressed'

/* Architecturally valid short-HFP selectors remain genuine coverage gaps. */
do r over .array~of(0,2,4,6)
  m~cpu~loadIPLPSW('0004000190000082')
  m~storage~storeHex(x2d('82'),'70'||d2x(r,1)||'00000')
  call eq 'UNSUPPORTED',m~executor~step,'valid STE R1='||r||' remains unsupported'
end

/* Validity preflight must win even if a future/live OP70 exists. */
call resetState
dummy="expose storage; use strict arg i,ia,t=0; storage~storeHex(0,'DEADBEEF'); return ia+4"
call truth m~executor~installLiveMethod('OP70',dummy),'install dummy OP70'
st=m~executor~step
call eq 'OK',st,'spec preflight before OP70'
call eq 'A1B2C3D4',m~storage~fetchHex(0,4),'dummy OP70 not executed'
call eq '0004000690000086',m~storage~fetchHex(x2d('28'),8),'preflight old PSW'
call truth m~executor~removeLiveMethod('OP70'),'remove dummy OP70'
say 'PASS test_program_specification_interrupt_70'
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
::requires 'IBM4361.cls'
