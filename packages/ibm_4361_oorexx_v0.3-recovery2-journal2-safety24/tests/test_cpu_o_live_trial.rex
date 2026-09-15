numeric digits 30
m=.IBM4361Machine~new(262144); m~powerOn
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); v=c2d(bitor(d2c(cpu~gprFast(f[1]),4),x2c(storage~fetchHex(ea,4)))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+4"
call truth m~executor~installLiveMethod('OP56',source),'install'
call one '00000000','00000000','00000000',0
call one '00000001','00000002','00000003',1
call one '80000000','00000001','80000001',1
call one '00035EC8','FC000000','FC035EC8',1
say 'PASS test_cpu_o_live_trial'; exit 0
one: procedure expose m
 use arg a,b,expected,cc
 m~cpu~loadIPLPSW('0000000000000100'); m~storage~storeHex(x2d('100'),'56100300'); m~storage~storeHex(x2d('300'),b); m~cpu~setGpr(1,x2d(a)); st=m~executor~step
 if st\=='OK' | d2x(m~cpu~gpr(1),8)\==expected | m~cpu~psw~conditionCode\==cc | m~storage~fetchHex(x2d('300'),4)\==b then do; say 'FAIL'; exit 1; end
return
truth: procedure; use arg x,l; if \x then do; say 'FAIL' l; exit 1; end; return
::requires 'IBM4361.cls'
