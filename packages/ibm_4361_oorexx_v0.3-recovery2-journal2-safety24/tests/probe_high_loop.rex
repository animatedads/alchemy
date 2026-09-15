numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 16000
 st=m~tick
 if st<>"OK" then do; say 'STOP' st n; leave; end
end
say 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CC='m~cpu~psw~conditionCode 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
say 'CODE='m~storage~fetchHex(x2d('FFE040'),64)
do r=0 to 15
 say 'R'r'='d2x(m~cpu~gpr(r),8)
end
exit 0
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
