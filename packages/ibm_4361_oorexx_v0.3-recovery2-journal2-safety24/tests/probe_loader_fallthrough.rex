numeric digits 30
log='/mnt/data/loader_fallthrough.log'; call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV'); dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 75000
 st=m~tick
 if st<>"OK" then do; call emit 'EARLY n='n' ST='st; exit 2; end
end
call emit 'AT75000 IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
lastR13=m~cpu~gpr(13)
do k=1 to 30000
 ia=m~cpu~psw~instructionAddress
 r13=m~cpu~gpr(13)
 if r13<=16 & r13<>lastR13 then call emit 'COUNT k='k 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'R13='d2x(r13,8)
 lastR13=r13
 if ia=x2d('FFE228') then call emit 'PRE_FFE228 k='k 'IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8) 'C50='m~storage~fetchHex(x2d('FFE620'),4)
 st=m~tick
 if ia=x2d('FFE228') then call emit 'POST_FFE228 k='k 'IC='m~cpu~instructionCount 'R6='d2x(m~cpu~gpr(6),8) 'NEXT='d2x(m~cpu~psw~instructionAddress,6)
 if k//2000=0 then call emit 'P k='k 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8) 'ST='st
 if st<>"OK" then do
   call emit 'STOP k='k 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'INST='m~executor~lastInstruction 'PSW='m~cpu~psw~rawHex 'ST='st
   do r=0 to 15; call emit 'R'r'='d2x(m~cpu~gpr(r),8); end
   leave
 end
end
call emit 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R6='d2x(m~cpu~gpr(6),8) 'R13='d2x(m~cpu~gpr(13),8) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ST='st
call lineout log
exit 0
emit: parse arg line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
