numeric digits 30
m=.IBM4361Machine~new(2097152)
m~powerOn

/* Masked MC is an architectural no-op. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~psw~setConditionCode(3)
m~storage~storeHex(x2d('016606'),'AF030FFF')
call eq 0,m~cpu~cr(8),'CR8 reset'
st=m~executor~step
call eq 'OK',st,'masked MC status'
call eq x2d('01660A'),m~cpu~psw~instructionAddress,'masked MC next IA'
call eq 1,m~cpu~instructionCount,'masked MC IC'
call eq 3,m~cpu~psw~conditionCode,'masked MC CC unchanged'

/* A different class may be enabled while class 3 remains masked. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~psw~setConditionCode(2)
m~cpu~setCr(8,x2d('8000')) /* class 0 only */
st=m~executor~step
call eq 'OK',st,'class 3 remains masked'
call eq 2,m~cpu~psw~conditionCode,'different mask CC unchanged'

/* The not-yet-proven monitor-event path deliberately fails closed. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~setCr(8,x2d('1000')) /* class 3 */
signal on syntax name enabled_expected
st=m~executor~step
say 'FAIL enabled class did not fail closed status='st
exit 1
enabled_expected:
signal off syntax

/* Reserved high nibble of I2 is a specification boundary. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~setCr(8,0)
m~storage~storeHex(x2d('016606'),'AF130FFF')
signal on syntax name reserved_expected
st=m~executor~step
say 'FAIL reserved MC did not fail closed status='st
exit 1
reserved_expected:
signal off syntax
say 'PASS test_cpu_mc'
exit 0

eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
::requires 'IBM4361.cls'
