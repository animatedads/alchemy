numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

call case m,'123C',2,'F2C3',3,'positive short'
call case m,'123D',2,'F2D3',1,'negative short'
call case m,'00013C',4,'F0F0F1C3',2,'left pad guest shape'
call case m,'12345C',2,'F4C5',0,'left truncate'
call baseCase m

say 'PASS test_cpu_unpk'
exit 0

case: procedure
  use arg m,packed,l1,expected,startCC,label
  m~cpu~loadIPLPSW('0000000000000100')
  m~cpu~psw~setConditionCode(startCC)
  l2=packed~length%2
  if packed~length//2<>0 then do; say 'FAIL malformed test packed' packed; exit 1; end
  /* UNPK l1,l2 at 0300 from 0400. */
  inst='F3'||d2x(l1-1,1)||d2x(l2-1,1)||'0300'||'0400'
  m~storage~storeHex(x2d('100'),inst)
  m~storage~storeHex(x2d('300'),'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
  m~storage~storeHex(x2d('400'),packed)
  st=m~executor~step
  if st \== 'OK' then do; say 'FAIL' label 'status' st; exit 1; end
  actual=m~storage~fetchHex(x2d('300'),l1)
  if actual \== expected then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
  if m~cpu~psw~conditionCode \== startCC then do; say 'FAIL' label 'CC changed expected='startCC 'actual='m~cpu~psw~conditionCode; exit 1; end
  if m~cpu~psw~instructionAddress \== x2d('106') then do; say 'FAIL' label 'IA expected=000106 actual='d2x(m~cpu~psw~instructionAddress,6); exit 1; end
return

baseCase: procedure
  use arg m
  m~cpu~loadIPLPSW('0000000000000100')
  m~cpu~psw~setConditionCode(3)
  m~cpu~setGpr(5,x2d('00000200'))
  m~cpu~setGpr(6,x2d('00000300'))
  /* UNPK 4,3 at 040(R5)=0240 from 080(R6)=0380. */
  m~storage~storeHex(x2d('100'),'F33250406080')
  m~storage~storeHex(x2d('240'),'AAAAAAAA')
  m~storage~storeHex(x2d('380'),'00013C')
  st=m~executor~step
  if st \== 'OK' then do; say 'FAIL base status' st; exit 1; end
  actual=m~storage~fetchHex(x2d('240'),4)
  if actual \== 'F0F0F1C3' then do; say 'FAIL base expected F0F0F1C3 actual='actual; exit 1; end
  if m~cpu~psw~conditionCode \== 3 then do; say 'FAIL base CC actual='m~cpu~psw~conditionCode; exit 1; end
return

::requires 'IBM4361.cls'
