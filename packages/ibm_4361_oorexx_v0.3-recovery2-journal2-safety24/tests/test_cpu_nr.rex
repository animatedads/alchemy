/* Safety10 permanent NR / And Register semantics. */
numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

call one 'FFFFFFFF','0F0F0F0F','0F0F0F0F',1
call one 'F0F0F0F0','0F0F0F0F','00000000',0
call one '80000000','FFFFFFFF','80000000',1
call one '00029960','00FFFFFF','00029960',1

m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'1444')
m~cpu~setGpr(4,x2d('A5A55A5A'))
st=m~executor~step
call eq 'OK',st,'same-register status'
call eq 'A5A55A5A',d2x(m~cpu~gpr(4),8),'same-register result'
call eq 1,m~cpu~psw~conditionCode,'same-register cc'

say 'PASS test_cpu_nr'
exit 0

one: procedure expose m
  use arg a,b,expected,cc
  m~cpu~loadIPLPSW('0000000000000100')
  m~storage~storeHex(x2d('100'),'1412')
  m~cpu~setGpr(1,x2d(a)); m~cpu~setGpr(2,x2d(b))
  st=m~executor~step
  if st\=='OK' | d2x(m~cpu~gpr(1),8)\==expected | d2x(m~cpu~gpr(2),8)\==b | m~cpu~psw~conditionCode\==cc then do
    say 'FAIL a='||a||' b='||b||' st='||st||' r1='||d2x(m~cpu~gpr(1),8)||' r2='||d2x(m~cpu~gpr(2),8)||' cc='||m~cpu~psw~conditionCode
    exit 1
  end
return

eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
::requires 'IBM4361.cls'
