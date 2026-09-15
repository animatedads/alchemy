numeric digits 30
log='/mnt/data/mvt_console_acceptance.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
lastOut=0
call emit 'START DEVICES=001F,0350'
do n=1 to 145000
  ia=m~cpu~psw~instructionAddress; inst=m~storage~fetchHex(ia,6); op=inst~left(2); ic=m~cpu~instructionCount
  packTrace=0
  if ic>=325000 & op='F2' then do
    l1=x2d(inst~substr(3,1))+1; l2=x2d(inst~substr(4,1))+1
    if l1=2 & l2=3 then do
      b1=x2d(inst~substr(5,1)); d1=x2d(inst~substr(6,3)); b2=x2d(inst~substr(9,1)); d2=x2d(inst~substr(10,3))
      a1=d1; if b1<>0 then a1=(a1+m~cpu~gpr(b1))//16777216
      a2=d2; if b2<>0 then a2=(a2+m~cpu~gpr(b2))//16777216
      call emit 'PACK_PRE IC='||ic||' IA='||d2x(ia,6)||' SRC='||m~storage~fetchHex(a2,l2)||' DST='||m~storage~fetchHex(a1,l1)||' A1='||d2x(a1,6)||' A2='||d2x(a2,6)
      packTrace=1
    end
  end
  ioTrace=0; unit=-1
  if op='9C' | op='9D' then do
    b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3)); ea=d; if b<>0 then ea=(ea+m~cpu~gpr(b))//16777216; unit=ea//65536
    if unit=x2d('00C0') | unit=x2d('001F') then do
      ioTrace=1
      call emit 'IO_PRE IC='||ic||' IA='||d2x(ia,6)||' OP='||op||' UNIT='||d2x(unit,4)||' ATTACHED='||m~channels~hasDevice(unit)||' CC='||m~cpu~psw~conditionCode
    end
  end
  st=m~tick
  if packTrace then call emit 'PACK_POST IC='||m~cpu~instructionCount||' DST='||m~storage~fetchHex(a1,l1)||' IA='||d2x(m~cpu~psw~instructionAddress,6)
  if ioTrace then call emit 'IO_POST IC='||m~cpu~instructionCount||' UNIT='||d2x(unit,4)||' CC='||m~cpu~psw~conditionCode||' ST='||st
  if con~outputRecordCount>lastOut then do
    do oi=lastOut to con~outputRecordCount-1
      call emit '3215_OUT IC='||m~cpu~instructionCount||' CMD='||con~outputRecordCommand(oi)||' HEX='||con~outputRecordHex(oi)
    end
    lastOut=con~outputRecordCount
  end
  if m~channels~hasActiveProgram(x2d('001F')) then do
    p=m~channels~activeProgram(x2d('001F'))
    /* A stable pending READ INQUIRY remains on its CCW; record it once and stop. */
    ccwhex=m~storage~fetchHex(p~currentCCWAddress,8)
    if ccwhex~left(2)='0A' then do
      call emit '3215_READ_PENDING IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' CCW='||ccwhex||' CCWA='||d2x(p~currentCCWAddress,6)||' OUT='||con~outputRecordCount
      leave
    end
  end
  if st<>'OK' then do; call emit 'STOP IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' PSW='||m~cpu~psw~rawHex||' ST='||st; leave; end
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
