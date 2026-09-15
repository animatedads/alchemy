numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 20000
 ia=m~cpu~psw~instructionAddress
 if ia>=x2d('614') & ia<=x2d('668') then do
   say 'PRE n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6)
   say ' R2='d2x(m~cpu~gpr(2),8) 'R3='d2x(m~cpu~gpr(3),8) 'R4='d2x(m~cpu~gpr(4),8) 'R5='d2x(m~cpu~gpr(5),8) 'R6='d2x(m~cpu~gpr(6),8) 'R7='d2x(m~cpu~gpr(7),8) 'R9='d2x(m~cpu~gpr(9),8) 'R15='d2x(m~cpu~gpr(15),8)
   if ia=x2d('646') then do
     say ' LOWC38='m~storage~fetchHex(x2d('C38'),4) 'HIC38='m~storage~fetchHex(x2d('FFE608'),4)
     say ' TEMPLATE@'d2x((m~cpu~gpr(15)+x2d('5D6'))//16777216,6)'='m~storage~fetchHex((m~cpu~gpr(15)+x2d('5D6'))//16777216,6)
   end
 end
 st=m~tick
 if st<>"OK" then do; say 'STOP' st; exit 2; end
 if m~cpu~psw~instructionAddress>=x2d('FF0000') then do; say 'ENTER HIGH IC='m~cpu~instructionCount 'HIC38='m~storage~fetchHex(x2d('FFE608'),4); exit 0; end
end
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
