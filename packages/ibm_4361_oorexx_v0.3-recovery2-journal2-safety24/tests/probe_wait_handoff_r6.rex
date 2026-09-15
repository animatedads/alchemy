numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 250000
 ia=m~cpu~psw~instructionAddress
 if ia=x2d('FFE228') then do
   say 'PRE FFE228 n='n 'IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8) 'C50='m~storage~fetchHex(x2d('FFE620'),4) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
   st=m~tick
   say 'POST FFE228 st='st 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R6='d2x(m~cpu~gpr(6),8)
   exit 0
 end
 st=m~tick
 if st<>"OK" then do; say 'STOP' st 'n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record; exit 2; end
end
say 'NOTFOUND IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
exit 1
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
