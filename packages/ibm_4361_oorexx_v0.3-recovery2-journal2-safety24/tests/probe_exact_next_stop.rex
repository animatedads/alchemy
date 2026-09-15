numeric digits 30
log='/mnt/data/mvt_exact_next_stop.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
do n=1 to 285000
 ia=m~cpu~psw~instructionAddress
 inst=m~storage~fetchHex(ia,6)
 st=m~tick
 if n//50000=0 then call emit 'PROGRESS n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)
 if st<>'OK' then do
   call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' INST='||inst||' OP='||inst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||st
   leave
 end
end
call emit 'END n='||n||' IC='||m~cpu~instructionCount
call lineout log
exit 0
emit:
 parse arg line
 call lineout log,line; call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
