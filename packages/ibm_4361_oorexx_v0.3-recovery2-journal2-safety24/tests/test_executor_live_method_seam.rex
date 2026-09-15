numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn
m~cpu~loadIPLPSW('0000000000000100')
m~cpu~setGpr(3,x2d('40000000'))
m~storage~storeHex(x2d('100'),'8A300001')
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; cpu~setGprFast(3,x2d('12345678')); cpu~psw~setConditionCode(3); return ia+4"
call truth m~executor~installLiveMethod('OP8A',source),'object live method installed'
st=m~executor~step
call eq 'OK',st,'trial status'
call eq '12345678',d2x(m~cpu~gpr(3),8),'object method overrides permanent OP8A'
call eq 3,m~cpu~psw~conditionCode,'object method CC'
say 'PASS test_executor_live_method_seam'
exit 0
eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg actual,label
  if \actual then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361.cls'
