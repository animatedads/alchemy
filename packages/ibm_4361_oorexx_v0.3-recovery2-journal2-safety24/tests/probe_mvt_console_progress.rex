numeric digits 30
log='/mnt/data/mvt_console_progress.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
lastOut=0
call emit 'START DEVICES=001F,0350'
do n=1 to 320000
  ia=m~cpu~psw~instructionAddress; inst=m~storage~fetchHex(ia,6); op=inst~left(2)
  unit=-1; ioTrace=0
  if op='9C' | op='9D' then do
    b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3)); ea=d; if b<>0 then ea=(ea+m~cpu~gpr(b))//16777216; unit=ea//65536
    if unit=x2d('001F') then do
      ioTrace=1
      if op='9C' then do
        caw=m~storage~fetchHex(x2d('48'),4); ca=x2d(caw~substr(3,6)); ccw=m~storage~fetchHex(ca,8)
        call emit '001F_SIO_PRE n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' CAW='||caw||' CCW='||ccw||' OUT='||con~outputRecordCount
      end
      else call emit '001F_TIO_PRE n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' OUT='||con~outputRecordCount
    end
  end
  st=m~tick
  if ioTrace then call emit '001F_IO_POST IC='||m~cpu~instructionCount||' CC='||m~cpu~psw~conditionCode||' ST='||st
  if con~outputRecordCount>lastOut then do
    do oi=lastOut to con~outputRecordCount-1
      call emit '3215_OUT IC='||m~cpu~instructionCount||' CMD='||con~outputRecordCommand(oi)||' HEX='||con~outputRecordHex(oi)
    end
    lastOut=con~outputRecordCount
  end
  if m~channels~hasActiveProgram(x2d('001F')) then do
    p=m~channels~activeProgram(x2d('001F')); ccwhex=m~storage~fetchHex(p~currentCCWAddress,8)
    if ccwhex~left(2)='0A' then do
      call emit '3215_READ_PENDING n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' CCWA='||d2x(p~currentCCWAddress,6)||' CCW='||ccwhex||' OUT='||con~outputRecordCount
      leave
    end
  end
  if n//25000=0 then do
    c=''; if m~channels~hasActiveProgram(x2d('350')) then c=' CCHHR='||dev~cylinder||'/'||dev~head||'/'||dev~record
    call emit 'PROGRESS n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||c||' OUT='||con~outputRecordCount
  end
  if st<>'OK' then do; call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' PSW='||m~cpu~psw~rawHex||' ST='||st||' OUT='||con~outputRecordCount; leave; end
end
call emit 'END n='||n||' IC='||m~cpu~instructionCount||' PSW='||m~cpu~psw~rawHex||' OUT='||con~outputRecordCount
call lineout log
exit 0
emit:
  parse arg line
  call lineout log,line; call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
