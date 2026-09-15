/* Safety11 permanent AL / Add Logical semantics. */
numeric digits 30
m=.IBM4361Machine~new(131072)
m~powerOn

call one '00000000','00000000','00000000',0
call one '00000001','00000001','00000002',1
call one 'FFFFFFFF','00000001','00000000',2
call one 'FFFFFFFF','00000002','00000001',3
call one '80016A60','40000000','C0016A60',1

/* Base/index RX addressing and storage immutability. */
m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'5E123020') /* R1=1,X2=2,B2=3,D2=020 */
m~cpu~setGpr(1,x2d('FFFFFFFE'))
m~cpu~setGpr(2,x2d('10')); m~cpu~setGpr(3,x2d('200'))
m~storage~storeHex(x2d('230'),'00000003')
st=m~executor~step
call eq 'OK',st,'indexed status'
call eq '00000001',d2x(m~cpu~gpr(1),8),'indexed result'
call eq 3,m~cpu~psw~conditionCode,'indexed cc'
call eq '00000003',m~storage~fetchHex(x2d('230'),4),'storage unchanged'

say 'PASS test_cpu_al'
exit 0

one: procedure expose m
  use arg a,b,expected,cc
  m~cpu~loadIPLPSW('0000000000000100')
  m~storage~storeHex(x2d('100'),'5E100300')
  m~storage~storeHex(x2d('300'),b)
  m~cpu~setGpr(1,x2d(a))
  st=m~executor~step
  if st\=='OK' | d2x(m~cpu~gpr(1),8)\==expected | m~cpu~psw~conditionCode\==cc | m~storage~fetchHex(x2d('300'),4)\==b then do
    say 'FAIL a='||a||' b='||b||' st='||st||' r1='||d2x(m~cpu~gpr(1),8)||' cc='||m~cpu~psw~conditionCode||' mem='||m~storage~fetchHex(x2d('300'),4)
    exit 1
  end
return

eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
::requires 'IBM4361.cls'
