/* Safety15 permanent ALR / Add Logical Register semantics. */
numeric digits 30
m=.IBM4361Machine~new(131072)
m~powerOn

call one '00000000','00000000','00000000',0
call one '00000001','00000001','00000002',1
call one 'FFFFFFFF','00000001','00000000',2
call one 'FFFFFFFF','00000002','00000001',3
call one '20000000','40000002','60000002',1

/* R1==R2 must read the pre-instruction value before storing. */
m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'1E11')
m~cpu~setGpr(1,x2d('80000000'))
st=m~executor~step
call eq 'OK',st,'alias status'
call eq '00000000',d2x(m~cpu~gpr(1),8),'alias result'
call eq 2,m~cpu~psw~conditionCode,'alias cc'

say 'PASS test_cpu_alr'
exit 0

one: procedure expose m
  use arg a,b,expected,cc
  m~cpu~loadIPLPSW('0000000000000100')
  m~storage~storeHex(x2d('100'),'1E12')
  m~cpu~setGpr(1,x2d(a)); m~cpu~setGpr(2,x2d(b))
  st=m~executor~step
  if st\=='OK' | d2x(m~cpu~gpr(1),8)\==expected | m~cpu~psw~conditionCode\==cc then do
    say 'FAIL a='||a||' b='||b||' st='||st||' r1='||d2x(m~cpu~gpr(1),8)||' cc='||m~cpu~psw~conditionCode
    exit 1
  end
return

eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
::requires 'IBM4361.cls'
