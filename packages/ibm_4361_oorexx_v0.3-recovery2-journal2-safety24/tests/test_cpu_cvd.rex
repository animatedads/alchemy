numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

call case m,'00000000','000000000000000C',3,'zero'
call case m,'00000001','000000000000001C',2,'positive one'
call case m,'FFFFFFFF','000000000000001D',1,'negative one'
call case m,'7FFFFFFF','000002147483647C',0,'maximum positive'
call case m,'80000000','000002147483648D',3,'minimum negative'
call indexedCase m

say 'PASS test_cpu_cvd'
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

indexedCase: procedure
  use arg m
  m~cpu~loadIPLPSW('0000000000000100')
  m~cpu~psw~setConditionCode(2)
  m~cpu~setGpr(5,x2d('FFFFFFF3'))  /* -13 */
  m~cpu~setGpr(6,x2d('00000020'))
  m~cpu~setGpr(7,x2d('00000200'))
  /* CVD R5,010(R6,R7) -> 0x230 */
  m~storage~storeHex(x2d('100'),'4E567010')
  m~storage~storeHex(x2d('230'),'FFFFFFFFFFFFFFFF')
  st=m~executor~step
  if st \== 'OK' then do; say 'FAIL indexed status' st; exit 1; end
  actual=m~storage~fetchHex(x2d('230'),8)
  if actual \== '000000000000013D' then do; say 'FAIL indexed packed actual='actual; exit 1; end
  if m~cpu~psw~conditionCode \== 2 then do; say 'FAIL indexed CC actual='m~cpu~psw~conditionCode; exit 1; end
return

::requires 'IBM4361.cls'
