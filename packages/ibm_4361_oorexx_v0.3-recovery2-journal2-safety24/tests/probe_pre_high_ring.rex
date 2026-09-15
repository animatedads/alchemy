numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
ring=.Array~new; max=160
do n=1 to 30000
 ia=m~cpu~psw~instructionAddress
 line='n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6) 'R6='d2x(m~cpu~gpr(6),8) 'R7='d2x(m~cpu~gpr(7),8) 'R13='d2x(m~cpu~gpr(13),8) 'R15='d2x(m~cpu~gpr(15),8) 'C50='m~storage~fetchHex(x2d('C50'),4)
 ring~append(line); if ring~items>max then ring~remove(1)
 st=m~tick
 if st<>"OK" then do; say 'STOP' st; leave; end
 nia=m~cpu~psw~instructionAddress
 if nia>=x2d('FF0000') then do
   say 'ENTER HIGH at' d2x(nia,6) 'IC='m~cpu~instructionCount
   do x over ring; say x; end
   say 'REGS'; do r=0 to 15; say 'R'r'='d2x(m~cpu~gpr(r),8); end
   exit 0
 end
end
say 'NOTFOUND'
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
