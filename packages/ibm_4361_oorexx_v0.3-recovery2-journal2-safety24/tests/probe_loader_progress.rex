numeric digits 30
parse arg maxTicks stride
if maxTicks="" then maxTicks=100000
if stride="" then stride=10000
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
start=time('R')
do n=1 to maxTicks
  st=m~tick
  if n//stride=0 | st<>"OK" then do
    say 'P' n 'ELAPSED='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'R6='d2x(m~cpu~gpr(6),8) 'R13='d2x(m~cpu~gpr(13),8) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ST='st
  end
  if st<>"OK" then leave
end
say 'END ELAPSED='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'R6='d2x(m~cpu~gpr(6),8) 'R13='d2x(m~cpu~gpr(13),8) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ST='st
exit 0
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
