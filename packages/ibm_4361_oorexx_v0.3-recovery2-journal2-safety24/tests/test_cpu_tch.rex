numeric digits 30
m=.IBM4361Machine~new(65536)
m~powerOn
con=.IBM3215Device~new(x2d('001F'))
disk=.IBM370IPLMemoryDevice~new(x2d('0350'),copies('00',24))
m~attachDevice(con)
m~attachDevice(disk)

call eq m~channels~testChannel(x2d('0000')),0,'channel 0 exists'
call eq m~channels~testChannel(x2d('0300')),0,'channel 3 exists'
call eq m~channels~testChannel(x2d('0100')),3,'channel 1 absent'

m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'9F000000')
st=m~executor~step
call eq st,'OK','TCH channel 0 status'
call eq m~cpu~psw~conditionCode,0,'TCH channel 0 CC'
call eq m~cpu~psw~instructionAddress,x2d('104'),'TCH channel 0 IA'

m~storage~storeHex(x2d('104'),'9F000100')
st=m~executor~step
call eq st,'OK','TCH channel 1 status'
call eq m~cpu~psw~conditionCode,3,'TCH absent channel CC'
call eq m~cpu~psw~instructionAddress,x2d('108'),'TCH channel 1 IA'

say 'PASS test_cpu_tch'
exit 0

eq: procedure
 parse arg actual,expected,label
 if actual \== expected then do
   say 'FAIL' label 'expected='expected 'actual='actual
   exit 1
 end
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
