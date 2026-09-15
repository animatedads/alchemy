numeric digits 30
log='/mnt/data/mvt_console_pack_path.log'
call lineout log
call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START DEVICES=001F,0350'
do n=1 to 112000
  ia=m~cpu~psw~instructionAddress
  inst=m~storage~fetchHex(ia,6)
  op=inst~left(2)
  near=(m~cpu~instructionCount>=329000)
  if near & op='F2' then do
    l1=x2d(inst~substr(3,1))+1; l2=x2d(inst~substr(4,1))+1
    b1=x2d(inst~substr(5,1)); d1=x2d(inst~substr(6,3)); b2=x2d(inst~substr(9,1)); d2=x2d(inst~substr(10,3))
    a1=d1; if b1<>0 then a1=(a1+m~cpu~gpr(b1))//16777216
    a2=d2; if b2<>0 then a2=(a2+m~cpu~gpr(b2))//16777216
    call emit 'PACK_PRE n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' INST='||inst||' A1='||d2x(a1,6)||' L1='||l1||' A2='||d2x(a2,6)||' L2='||l2||' SRC='||m~storage~fetchHex(a2,l2)||' DST='||m~storage~fetchHex(a1,l1)
    st=m~tick
    call emit 'PACK_POST IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' DST='||m~storage~fetchHex(a1,l1)||' ST='||st
  end
  else do
    if near & (op='9C' | op='9D') then do
      b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3)); ea=d; if b<>0 then ea=(ea+m~cpu~gpr(b))//16777216
      unit=ea//65536
      call emit 'IO_PRE n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' OP='||op||' UNIT='||d2x(unit,4)||' ATTACHED='||m~channels~hasDevice(unit)||' CC='||m~cpu~psw~conditionCode
    end
    st=m~tick
    if near & (op='9C' | op='9D') then call emit 'IO_POST IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' CC='||m~cpu~psw~conditionCode||' ST='||st
  end
  if st<>'OK' then do
    call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' PSW='||m~cpu~psw~rawHex||' ST='||st
    leave
  end
end
call emit 'END n='||n||' IC='||m~cpu~instructionCount||' PSW='||m~cpu~psw~rawHex
call lineout log
exit 0
emit:
  parse arg line
  call lineout log,line
  call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
