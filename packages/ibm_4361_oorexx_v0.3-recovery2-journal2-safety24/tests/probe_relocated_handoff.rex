numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 60000
 ia=m~cpu~psw~instructionAddress
 if ia>=x2d('FFE210') & ia<=x2d('FFE250') then do
  say 'PRE n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6) 'R6='d2x(m~cpu~gpr(6),8) 'R10='d2x(m~cpu~gpr(10),8) 'HC50='m~storage~fetchHex(x2d('FFE620'),4)
 end
 st=m~tick
 if st<>"OK" then do; say 'STOP' st 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6); exit 2; end
 if ia=x2d('FFE228') then say 'POST L R6 IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8)
end
say 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R6='d2x(m~cpu~gpr(6),8)
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
