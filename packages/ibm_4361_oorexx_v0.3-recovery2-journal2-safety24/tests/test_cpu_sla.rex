numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

call case m,'00000001',1,'00000002',2,'positive'
call case m,'FFFFFFFE',1,'FFFFFFFC',1,'negative no overflow'
call case m,'00000000',11,'00000000',0,'zero'
call case m,'40000000',1,'00000000',3,'positive overflow'
call case m,'BFFFFFFF',1,'FFFFFFFE',3,'negative overflow'
call case m,'FFFFFFFF',0,'FFFFFFFF',1,'zero shift negative'

say 'PASS test_cpu_sla'
exit 0

case: procedure
  use arg m,startHex,count,expectedHex,expectedCC,label
  m~cpu~loadIPLPSW('0000000000000100')
  m~cpu~setGpr(5,x2d(startHex))
  /* SLA R5,count: 8B 50 0ddd */
  m~storage~storeHex(x2d('100'),'8B50'||d2x(count,4))
  st=m~executor~step
  if st \== 'OK' then do; say 'FAIL' label 'status' st; exit 1; end
  actual=d2x(m~cpu~gpr(5),8)
  if actual \== expectedHex then do; say 'FAIL' label 'value expected='expectedHex 'actual='actual; exit 1; end
  if m~cpu~psw~conditionCode \== expectedCC then do; say 'FAIL' label 'CC expected='expectedCC 'actual='m~cpu~psw~conditionCode; exit 1; end
return
::requires 'IBM4361.cls'
