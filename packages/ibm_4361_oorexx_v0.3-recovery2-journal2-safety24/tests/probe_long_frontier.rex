numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(.IBM3330Device~new(x2d('350'),media)); m~initialProgramLoad(x2d('350'))
max=500000
do n=1 to max
  st=m~tick
  if n//25000=0 | st<>"OK" then do
    d=m~channels~device(x2d('350')); ap='-'; lc='-'
    if m~channels~hasActiveProgram(x2d('350')) then do; p=m~channels~activeProgram(x2d('350')); ap=d2x(p~currentCCWAddress,6); lc=d2x(p~lastCommand,2); end
    say 'P' n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'CC='m~cpu~psw~conditionCode 'CCHHR='d~cylinder'/'d~head'/'d~record 'AP='ap 'CMD='lc 'ST='st
  end
  if st<>"OK" then leave
end
exit 0
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
