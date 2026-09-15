numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); v=self~s32(cpu~gprFast(f[1])); sign='C'; if v<0 then do; sign='D'; v=-v; end; packed=v~string~right(15,'0')||sign; storage~storeHex(ea,packed); return ia+4"
call truth m~executor~installLiveMethod('OP4E',source),'live CVD method installed'

call case m,'00000000','000000000000000C',3,'zero'
call case m,'00000001','000000000000001C',2,'positive one'
call case m,'FFFFFFFF','000000000000001D',1,'negative one'
call case m,'7FFFFFFF','000002147483647C',0,'maximum positive'
call case m,'80000000','000002147483648D',3,'minimum negative'

say 'PASS test_cpu_cvd_live_trial'
exit 0

case: procedure
  use arg m,startHex,expectedHex,startCC,label
  m~cpu~loadIPLPSW('0000000000000100')
  m~cpu~psw~setConditionCode(startCC)
  m~cpu~setGpr(1,x2d(startHex))
  /* CVD R1,0300: 4E 10 0300 */
  m~storage~storeHex(x2d('100'),'4E100300')
  m~storage~storeHex(x2d('300'),'FFFFFFFFFFFFFFFF')
  st=m~executor~step
  if st \== 'OK' then do; say 'FAIL' label 'status' st; exit 1; end
  actual=m~storage~fetchHex(x2d('300'),8)
  if actual \== expectedHex then do; say 'FAIL' label 'packed expected='expectedHex 'actual='actual; exit 1; end
  if m~cpu~psw~conditionCode \== startCC then do; say 'FAIL' label 'CC changed expected='startCC 'actual='m~cpu~psw~conditionCode; exit 1; end
  if m~cpu~psw~instructionAddress \== x2d('104') then do; say 'FAIL' label 'IA expected=000104 actual='d2x(m~cpu~psw~instructionAddress,6); exit 1; end
return

truth: procedure
  use arg actual,label
  if \actual then do; say 'FAIL' label; exit 1; end
return

::requires 'IBM4361.cls'
