numeric digits 30
parse arg maxTicks
if maxTicks="" then maxTicks=56000
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
dummy=time('R')
do n=1 to maxTicks
  ia=m~cpu~psw~instructionAddress
  st=m~tick
  if n>=50000 & (n//1000=0 | st<>"OK") then do
    inst=m~storage~fetchHex(m~cpu~psw~instructionAddress,6)
    say 'P' n 'T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'INST='inst 'OP='d2x(m~executor~lastOpcode,2) 'R6='d2x(m~cpu~gpr(6),8) 'R7='d2x(m~cpu~gpr(7),8) 'R9='d2x(m~cpu~gpr(9),8) 'R13='d2x(m~cpu~gpr(13),8) 'ST='st
  end
  if st<>"OK" then leave
end
say 'END' maxTicks 'T='format(time('E'),,3) 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R13='d2x(m~cpu~gpr(13),8)
exit 0
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
