/* Safety9 pre-promotion live LCR semantics. */
numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn
m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'1301')
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; f=self~rr(i); v=self~s32(cpu~gprFast(f[2])); if v=-2147483648 then do; if cpu~psw~programMask>=8 then raise syntax 40.900 array('LCR fixed-point-overflow interruption path not yet implemented'); cpu~setGprFast(f[1],2147483648); cpu~psw~setConditionCode(3); end; else do; r=-v; cpu~setGprFast(f[1],self~u32(r)); self~ccSigned(r); end; return ia+2"
call truth m~executor~installLiveMethod('OP13',source),'install OP13'

call one 0,'00000000',0
call one 1,'FFFFFFFF',1
call one -1,'00000001',2
call one 12,'FFFFFFF4',1
call one -12,'0000000C',2
call one -2147483648,'80000000',3
say 'PASS test_cpu_lcr_live_trial'
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

truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361.cls'
