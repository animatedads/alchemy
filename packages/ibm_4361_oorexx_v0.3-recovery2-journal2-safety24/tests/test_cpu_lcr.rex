numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

call one 0,'00000000',0
call one 1,'FFFFFFFF',1
call one -1,'00000001',2
call one 12,'FFFFFFF4',1
call one -12,'0000000C',2
call one -2147483648,'80000000',3

/* Masked fixed-point overflow is deliberately not fabricated yet. */
m~cpu~loadIPLPSW('0000000000000100')
m~cpu~psw~setProgramMask(8)
m~cpu~setGpr(1,x2d('80000000'))
m~storage~storeHex(x2d('100'),'1301')
signal on syntax name masked
st=m~executor~step
signal off syntax
say 'FAIL masked overflow unexpectedly returned' st
exit 1
masked:
signal off syntax
call eq x2d('80000000'),m~cpu~gpr(1),'masked overflow source preserved before unimplemented interrupt'
call eq x2d('100'),m~cpu~psw~instructionAddress,'masked overflow IA preserved'

say 'PASS test_cpu_lcr'
exit 0

one: procedure expose m
  use arg input,expected,cc
  m~cpu~loadIPLPSW('0000000000000100')
  m~storage~storeHex(x2d('100'),'1301')
  if input<0 then u=input+4294967296; else u=input
  m~cpu~setGpr(1,u)
  st=m~executor~step
  if st\=='OK' | d2x(m~cpu~gpr(0),8)\==expected | m~cpu~psw~conditionCode\==cc then do
    say 'FAIL input='input 'st='st 'r0='d2x(m~cpu~gpr(0),8) 'cc='m~cpu~psw~conditionCode
    exit 1
  end
return

eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
::requires 'IBM4361.cls'
