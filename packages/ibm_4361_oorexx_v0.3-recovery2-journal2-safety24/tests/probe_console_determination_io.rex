numeric digits 30
log='/mnt/data/mvt_console_det_io.log'
call lineout log
call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START DEVICES=001F,0350'
do n=1 to 110000
  ia=m~cpu~psw~instructionAddress
  inst=m~storage~fetchHex(ia,4)
  op=inst~left(2)
  traceIO=(m~cpu~instructionCount>=329000 & (op='9C' | op='9D'))
  if traceIO then do
    b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3)); ea=d; if b<>0 then ea=(ea+m~cpu~gpr(b))//16777216
    unit=ea//65536
    line='IO_PRE n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' OP='||op||' INST='||inst||' B='||b||' D='||d2x(d,3)||' EA='||d2x(ea,6)||' UNIT='||d2x(unit,4)||' ATTACHED='||m~channels~hasDevice(unit)||' CC='||m~cpu~psw~conditionCode; call emit line
  end
  st=m~tick
  if traceIO then call emit 'IO_POST n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CC='m~cpu~psw~conditionCode 'ST='st
  if st<>'OK' then do
    call emit 'STOP n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'PSW='m~cpu~psw~rawHex 'ST='st
    leave
  end
end
call emit 'END n='n 'IC='m~cpu~instructionCount 'PSW='m~cpu~psw~rawHex
call lineout log
exit 0
emit:
 parse arg line
 call lineout log,line
 call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
