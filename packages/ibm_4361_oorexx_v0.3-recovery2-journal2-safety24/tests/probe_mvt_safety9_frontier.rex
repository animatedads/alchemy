numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_safety9_permanent_frontier.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
do n=1 to 300000
 ia=m~cpu~psw~instructionAddress; inst=m~storage~fetchHex(ia,6); ic=m~cpu~instructionCount
 if ic>=511860 then call emit 'PRE IC='||ic||' IA='||d2x(ia,6)||' INST='||inst||' PSW='||m~cpu~psw~rawHex||' R7='||d2x(m~cpu~gpr(7),8)||' CC='||m~cpu~psw~conditionCode
 st=m~tick
 if st<>'OK' then do; call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' INST='||inst||' OP='||inst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||st; leave; end
end
call emit 'END'; call lineout log
exit 0
emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
