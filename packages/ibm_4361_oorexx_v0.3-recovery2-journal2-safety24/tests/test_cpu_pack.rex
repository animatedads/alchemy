numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn
m~cpu~loadIPLPSW('0000000000000100')

/* PACK 3 zoned bytes at 0200 into 2 packed bytes at 0300.\n * F1 F2 C3 -> digits 1,2,3 and sign C -> 12 3C. */
m~storage~storeHex(x2d('100'),'F21203000200')
m~storage~storeHex(x2d('200'),'F1F2C3')
m~storage~storeHex(x2d('300'),'FFFF')
st=m~executor~step
call eq st,'OK','basic status'
call eq m~storage~fetchHex(x2d('300'),2),'123C','basic packed result'
call eq m~cpu~psw~instructionAddress,x2d('106'),'basic IA'

/* Destination one byte: retain the low-order digit and sign. F1 C2 -> 2C. */
m~cpu~psw~setInstructionAddress(x2d('110'))
m~storage~storeHex(x2d('110'),'F20103100210')
m~storage~storeHex(x2d('210'),'F1C2')
m~storage~storeHex(x2d('310'),'FF')
st=m~executor~step
call eq st,'OK','truncate status'
call eq m~storage~fetchHex(x2d('310'),1),'2C','high-order truncation'

/* Destination longer than source: pad packed high-order digits with zero. */
m~cpu~psw~setInstructionAddress(x2d('120'))
m~storage~storeHex(x2d('120'),'F22103200220')
m~storage~storeHex(x2d('220'),'F4D5')
m~storage~storeHex(x2d('320'),'FFFFFF')
st=m~executor~step
call eq st,'OK','pad status'
call eq m~storage~fetchHex(x2d('320'),3),'00045D','leading zero padding'

say 'PASS test_cpu_pack'
exit 0

eq: procedure
  parse arg actual,expected,label
  if actual \== expected then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
return

::requires 'IBM4361.cls'
