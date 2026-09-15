numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
dummy=time('R')
do n=1 to 56000
 st=m~tick
 if st<>"OK" then do; say 'EARLY STOP' n st; exit 2; end
end
say 'AT56000 T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
do k=1 to 2000
 ia=m~cpu~psw~instructionAddress
 inst=m~storage~fetchHex(ia,6)
 t=time('E')
 st=m~tick
 dt=time('E')-t
 if dt>.01 | k//100=0 | st<>"OK" then say 'K' k 'DT='format(dt,,6) 'IA='d2x(ia,6) 'INST='inst 'NEXT='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'R6='d2x(m~cpu~gpr(6),8) 'R7='d2x(m~cpu~gpr(7),8) 'R13='d2x(m~cpu~gpr(13),8) 'ST='st
 if st<>"OK" then leave
end
say 'END T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
