numeric digits 30
log='/mnt/data/after56k_progress.log'
call lineout log
call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 56000
 st=m~tick
 if st<>"OK" then do; call emit 'EARLY STOP 'n' 'st; exit 2; end
end
call emit 'AT56000 IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
do k=1 to 3000
 ia=m~cpu~psw~instructionAddress
 inst=m~storage~fetchHex(ia,6)
 call emit 'PRE K='k 'IA='d2x(ia,6) 'INST='inst 'R6='d2x(m~cpu~gpr(6),8) 'R7='d2x(m~cpu~gpr(7),8) 'R9='d2x(m~cpu~gpr(9),8) 'R13='d2x(m~cpu~gpr(13),8)
 st=m~tick
 if st<>"OK" then do; call emit 'STOP K='k 'ST='st 'NEXT='d2x(m~cpu~psw~instructionAddress,6); leave; end
end
call emit 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
call lineout log
exit 0
emit:
  parse arg line
  call lineout log,line
  call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
