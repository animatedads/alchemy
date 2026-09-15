/* Safety11 pre-promotion/live AL semantics. */
numeric digits 30
m=.IBM4361Machine~new(131072)
m~powerOn
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); a=cpu~gprFast(f[1]); b=x2d(storage~fetchHex(ea,4)); exact=a+b; carry=(exact>=4294967296); v=exact//4294967296; cpu~setGprFast(f[1],v); if carry then do; if v=0 then cc=2; else cc=3; end; else do; if v=0 then cc=0; else cc=1; end; cpu~psw~setConditionCode(cc); return ia+4"
call truth m~executor~installLiveMethod('OP5E',source),'install OP5E'

call one '00000000','00000000','00000000',0
call one '00000001','00000001','00000002',1
call one 'FFFFFFFF','00000001','00000000',2
call one 'FFFFFFFF','00000002','00000001',3
call one '80016A60','40000000','C0016A60',1

say 'PASS test_cpu_al_live_trial'
exit 0

one: procedure expose m
  use arg a,b,expected,cc
  m~cpu~loadIPLPSW('0000000000000100')
  m~storage~storeHex(x2d('100'),'5E100300')
  m~storage~storeHex(x2d('300'),b)
  m~cpu~setGpr(1,x2d(a))
  st=m~executor~step
  if st\=='OK' | d2x(m~cpu~gpr(1),8)\==expected | m~cpu~psw~conditionCode\==cc | m~storage~fetchHex(x2d('300'),4)\==b then do
    say 'FAIL a='||a||' b='||b||' st='||st||' r1='||d2x(m~cpu~gpr(1),8)||' cc='||m~cpu~psw~conditionCode
    exit 1
  end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361.cls'
