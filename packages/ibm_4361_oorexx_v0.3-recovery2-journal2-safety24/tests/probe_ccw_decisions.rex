numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
wasActive=0
startNo=0
lastStep=-1
lastCyl=-1
max=15000
do n=1 to max
  st=m~tick
  isActive=m~channels~hasActiveProgram(x2d('350'))
  if isActive & \wasActive then do
    startNo=startNo+1; lastStep=-1
    say 'SIO' startNo 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CAW='m~storage~fetchHex(x2d('48'),4) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ORI='dev~orientation
  end
  if isActive then do
    p=m~channels~activeProgram(x2d('350'))
    if p~steps<>lastStep then do
      lastStep=p~steps
      cmd=p~lastCommand
      if cmd>=0 then say ' CCW step='p~steps 'addr='d2x(p~lastCCWAddress,6) 'cmd='d2x(cmd,2) 'next='d2x(p~currentCCWAddress,6) 'res='p~residual 'us='d2x(p~unitStatus,2) 'cs='d2x(p~channelStatus,2) 'fm='d2x(p~fileMask,2) 'idx='p~indexMark 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ORI='dev~orientation
    end
  end
  wasActive=isActive
  if dev~cylinder<>lastCyl then do
    lastCyl=dev~cylinder
    say 'CYL' lastCyl 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'ST='st
  end
  if st<>"OK" then do; say 'STOP' st; leave; end
end
say 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
exit 0
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
