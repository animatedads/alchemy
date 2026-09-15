numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 30000
 ia=m~cpu~psw~instructionAddress
 if (ia>=x2d('830') & ia<=x2d('8C0')) | ia=x2d('16C') | (ia>=x2d('FFE000') & ia<=x2d('FFE080')) then do
   say 'PRE n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6) 'R6='d2x(m~cpu~gpr(6),8) 'R10='d2x(m~cpu~gpr(10),8) 'C50='m~storage~fetchHex(x2d('C50'),4)
 end
 st=m~tick
 if st<>"OK" then do; say 'STOP' st n 'IA='d2x(m~cpu~psw~instructionAddress,6); exit 2; end
 if m~cpu~psw~instructionAddress=x2d('FFE038') then do
   say 'ARRIVE FFE038 IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8) 'FFE608='m~storage~fetchHex(x2d('FFE608'),4)
   exit 0
 end
end
say 'NOTFOUND IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6)
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
