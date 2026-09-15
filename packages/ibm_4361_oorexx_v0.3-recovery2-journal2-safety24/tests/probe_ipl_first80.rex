numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
say 'START C50='m~storage~fetchHex(x2d('C50'),8)
do n=1 to 80
 ia=m~cpu~psw~instructionAddress
 say right(n,3) 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6) 'R6='d2x(m~cpu~gpr(6),8) 'R9='d2x(m~cpu~gpr(9),8) 'C50='m~storage~fetchHex(x2d('C50'),8)
 st=m~tick
 if st<>"OK" then do; say 'STOP' st; leave; end
end
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
