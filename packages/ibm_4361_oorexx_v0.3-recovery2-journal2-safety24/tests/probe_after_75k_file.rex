numeric digits 30
log='/mnt/data/after75k_progress.log'; call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV'); dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 75000; st=m~tick; if st<>"OK" then do; call emit 'EARLY 'n' 'st; exit 2; end; end
call emit 'AT75000 IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
do k=1 to 30000
 if k//100=1 then call emit 'PRE k='k 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8) 'INST='m~storage~fetchHex(m~cpu~psw~instructionAddress,6)
 st=m~tick
 if st<>"OK" then do; call emit 'STOP k='k 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'INST='m~executor~lastInstruction 'ST='st; leave; end
end
call emit 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8) 'ST='st
call lineout log
exit 0
emit: parse arg line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
