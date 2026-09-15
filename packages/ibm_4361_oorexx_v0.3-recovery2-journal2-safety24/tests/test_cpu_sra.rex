numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

call case m,'40000000',1,'20000000',2,'positive'
call case m,'80000000',1,'C0000000',1,'negative'
call case m,'FFFFFFFF',1,'FFFFFFFF',1,'negative odd'
call case m,'00000000',17,'00000000',0,'zero'
call case m,'7FFFFFFF',31,'00000000',0,'positive count31'
call case m,'80000000',31,'FFFFFFFF',1,'negative count31'
call case m,'80000000',63,'FFFFFFFF',1,'negative count63'
call case m,'FFFFFFFF',0,'FFFFFFFF',1,'zero shift negative'

say 'PASS test_cpu_sra'
exit 0

case: procedure
  use arg m,startHex,count,expectedHex,expectedCC,label
  m~cpu~loadIPLPSW('0000000000000100')
  m~cpu~setGpr(3,x2d(startHex))
  /* SRA R3,count: 8A 30 0ddd */
  m~storage~storeHex(x2d('100'),'8A30'||d2x(count,4))
  st=m~executor~step
  if st \== 'OK' then do; say 'FAIL' label 'status' st; exit 1; end
  actual=d2x(m~cpu~gpr(3),8)
  if actual \== expectedHex then do; say 'FAIL' label 'value expected='expectedHex 'actual='actual; exit 1; end
  if m~cpu~psw~conditionCode \== expectedCC then do; say 'FAIL' label 'CC expected='expectedCC 'actual='m~cpu~psw~conditionCode; exit 1; end
return
::requires 'IBM4361.cls'
