/* Safety12 permanent O / Or storage semantics. */
numeric digits 30
m=.IBM4361Machine~new(262144)
m~powerOn
call one '00000000','00000000','00000000',0
call one '00000001','00000002','00000003',1
call one '80000000','00000001','80000001',1
call one '00035EC8','FC000000','FC035EC8',1
/* indexed addressing */
m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'56123020')
m~cpu~setGpr(1,x2d('00F000F0')); m~cpu~setGpr(2,x2d('10')); m~cpu~setGpr(3,x2d('200'))
m~storage~storeHex(x2d('230'),'0F00000F')
st=m~executor~step
call eq 'OK',st,'indexed status'; call eq '0FF000FF',d2x(m~cpu~gpr(1),8),'indexed result'; call eq 1,m~cpu~psw~conditionCode,'indexed cc'; call eq '0F00000F',m~storage~fetchHex(x2d('230'),4),'storage unchanged'
say 'PASS test_cpu_o'; exit 0
one: procedure expose m
 use arg a,b,expected,cc
 m~cpu~loadIPLPSW('0000000000000100'); m~storage~storeHex(x2d('100'),'56100300'); m~storage~storeHex(x2d('300'),b); m~cpu~setGpr(1,x2d(a)); st=m~executor~step
 if st\=='OK' | d2x(m~cpu~gpr(1),8)\==expected | m~cpu~psw~conditionCode\==cc | m~storage~fetchHex(x2d('300'),4)\==b then do; say 'FAIL' a b expected cc 'actual' d2x(m~cpu~gpr(1),8) m~cpu~psw~conditionCode; exit 1; end
return
eq: procedure; use arg e,a,l; if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
::requires 'IBM4361.cls'
