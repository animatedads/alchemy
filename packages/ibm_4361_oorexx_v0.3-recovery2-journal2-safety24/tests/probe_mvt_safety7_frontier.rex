numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_safety7_frontier.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
lastOut=0
call emit 'START DEVICES=001F,0350'
do n=1 to 300000
  ia=m~cpu~psw~instructionAddress
  inst=m~storage~fetchHex(ia,6)
  st=m~tick
  if con~outputRecordCount>lastOut then do
    do oi=lastOut to con~outputRecordCount-1
      call emit '3215_OUT IC='||m~cpu~instructionCount||' CMD='||con~outputRecordCommand(oi)||' HEX='||con~outputRecordHex(oi)
    end
    lastOut=con~outputRecordCount
  end
  if n//25000=0 then do
    c=''; if m~channels~hasActiveProgram(x2d('350')) then c=' CCHHR='||dev~cylinder||'/'||dev~head||'/'||dev~record
    call emit 'PROGRESS n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||c||' OUT='||con~outputRecordCount
  end
  if st<>'OK' then do
    call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' PREIA='||d2x(ia,6)||' POSTIA='||d2x(m~cpu~psw~instructionAddress,6)||' INST='||inst||' OP='||inst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||st||' OUT='||con~outputRecordCount
    leave
  end
end
call emit 'END n='||n||' IC='||m~cpu~instructionCount||' PSW='||m~cpu~psw~rawHex||' OUT='||con~outputRecordCount
call lineout log
if st='OK' then do
  say 'FAIL no frontier within probe window'; exit 2
end
say 'FRONTIER IA='||d2x(ia,6)||' IC='||m~cpu~instructionCount||' INST='||inst||' OP='||inst~left(2)||' ST='||st
exit 0

emit:
  parse arg line
  say line
  call lineout log,line; call lineout log
return

::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
