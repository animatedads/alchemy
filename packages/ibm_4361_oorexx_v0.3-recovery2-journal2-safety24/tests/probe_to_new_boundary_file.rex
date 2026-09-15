numeric digits 30
parse arg maxTicks
if maxTicks="" then maxTicks=150000
log='/mnt/data/mvt_new_boundary.log'
call lineout log
call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
dummy=time('R')
do n=1 to maxTicks
 ia=m~cpu~psw~instructionAddress
 if ia=x2d('FFE228') then call emit 'PRE_FFE228 n='n 'IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8) 'C50='m~storage~fetchHex(x2d('FFE620'),4)
 st=m~tick
 if ia=x2d('FFE228') then call emit 'POST_FFE228 n='n 'IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8) 'NEXT='d2x(m~cpu~psw~instructionAddress,6)
 if n//5000=0 | st<>"OK" then call emit 'P n='n 'T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'R6='d2x(m~cpu~gpr(6),8) 'R13='d2x(m~cpu~gpr(13),8) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ST='st
 if st<>"OK" then do
   call emit 'STOP n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'INST='m~executor~lastInstruction 'PSW='m~cpu~psw~rawHex
   do r=0 to 15; call emit 'R'r'='d2x(m~cpu~gpr(r),8); end
   leave
 end
end
call emit 'END n='n 'T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R6='d2x(m~cpu~gpr(6),8) 'R13='d2x(m~cpu~gpr(13),8) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ST='st
call lineout log
exit 0
emit:
 parse arg line
 call lineout log,line
 call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
