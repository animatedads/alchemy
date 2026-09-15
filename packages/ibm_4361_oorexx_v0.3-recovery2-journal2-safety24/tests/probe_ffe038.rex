numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 40000
 ia=m~cpu~psw~instructionAddress
 if ia=x2d('FFE038') then do
   say 'FOUND n='n 'IC='m~cpu~instructionCount 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
   say 'CODE='m~storage~fetchHex(x2d('FFE020'),128)
   do r=0 to 15; say 'R'r'='d2x(m~cpu~gpr(r),8); end
   say 'FFE600='m~storage~fetchHex(x2d('FFE600'),64)
   exit 0
 end
 st=m~tick
 if st<>"OK" then do; say 'STOP' st n 'IA='d2x(m~cpu~psw~instructionAddress,6); exit 2; end
end
say 'NOTFOUND'; exit 1
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
