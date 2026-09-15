numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn

source="expose storage; use strict arg i,ia,t=0; l1=x2d(i~substr(3,1))+1; l2=x2d(i~substr(4,1))+1; b1=x2d(i~substr(5,1)); d1=x2d(i~substr(6,3)); b2=x2d(i~substr(9,1)); d2=x2d(i~substr(10,3)); a1=self~eaBD(b1,d1); a2=self~eaBD(b2,d2); packed=storage~fetchHex(a2,l2); sign=packed~right(1); digits=packed~left(packed~length-1); if digits~length>l1 then digits=digits~right(l1); else digits=digits~right(l1,'0'); zoned=''; do p=1 to l1; zone='F'; if p=l1 then zone=sign; zoned=zoned||zone||digits~substr(p,1); end; storage~storeHex(a1,zoned); return ia+6"
call truth m~executor~installLiveMethod('OPF3',source),'live UNPK installed'

m~cpu~loadIPLPSW('0000000000000100')
m~cpu~psw~setConditionCode(3)
m~storage~storeHex(x2d('100'),'F33203000400')
m~storage~storeHex(x2d('300'),'AAAAAAAA')
m~storage~storeHex(x2d('400'),'00013C')
st=m~executor~step
if st \== 'OK' then do; say 'FAIL status' st; exit 1; end
if m~storage~fetchHex(x2d('300'),4) \== 'F0F0F1C3' then do; say 'FAIL result' m~storage~fetchHex(x2d('300'),4); exit 1; end
if m~cpu~psw~conditionCode \== 3 then do; say 'FAIL CC changed'; exit 1; end

say 'PASS test_cpu_unpk_live_trial'
exit 0

truth: procedure
  use arg actual,label
  if \actual then do; say 'FAIL' label; exit 1; end
return

::requires 'IBM4361.cls'
