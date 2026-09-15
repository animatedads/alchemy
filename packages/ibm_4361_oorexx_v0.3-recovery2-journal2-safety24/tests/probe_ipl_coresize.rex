numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
last=m~storage~fetchHex(x2d('C50'),8)
say 'START IA='d2x(m~cpu~psw~instructionAddress,6) 'C50='last 'R9='d2x(m~cpu~gpr(9),8) 'R6='d2x(m~cpu~gpr(6),8)
do n=1 to 5000
 ia=m~cpu~psw~instructionAddress
 if ia=x2d('D0') | ia=x2d('D4') | ia=x2d('D8') | ia=x2d('858') | ia=x2d('85C') then
   say 'PRE n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6) 'C50='m~storage~fetchHex(x2d('C50'),8) 'R9='d2x(m~cpu~gpr(9),8) 'R6='d2x(m~cpu~gpr(6),8)
 st=m~tick
 cur=m~storage~fetchHex(x2d('C50'),8)
 if cur<>last then do
   say 'C50 CHANGE n='n 'POSTIA='d2x(m~cpu~psw~instructionAddress,6) 'old='last 'new='cur 'R9='d2x(m~cpu~gpr(9),8) 'R6='d2x(m~cpu~gpr(6),8)
   last=cur
 end
 if st<>"OK" then do; say 'STOP' st n 'IA='d2x(m~cpu~psw~instructionAddress,6); exit 2; end
end
say 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'C50='m~storage~fetchHex(x2d('C50'),8)
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
