numeric digits 30
parse arg maxTicks stride
if maxTicks="" then maxTicks=160000
if stride="" then stride=5000
log='/mnt/data/mvt_3215_probe.log'
call lineout log
call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn
m~attachDevice(dev)
m~attachDevice(con)
m~initialProgramLoad(x2d('350'))
seenOut=0
call emit 'START DEVICES='joinDevices(m~channels~deviceNumbers)
dummy=time('R')
do n=1 to maxTicks
  st=m~tick
  if con~outputRecordCount>seenOut then do
    do j=seenOut to con~outputRecordCount-1
      call emit '3215_OUT n='n 'IC='m~cpu~instructionCount 'CMD='d2x(con~outputRecordCommand(j),2) 'HEX='con~outputRecordHex(j)
    end
    seenOut=con~outputRecordCount
  end
  if n//stride=0 | st<>"OK" then do
    extra=''
    if m~channels~hasActiveProgram(x2d('001F')) then do
      p=m~channels~activeProgram(x2d('001F'))
      ca=p~currentCCWAddress
      extra=' CONACTIVE=1 CONCCW='d2x(ca,6)':'m~storage~fetchHex(ca,8)
    end
    else extra=' CONACTIVE=0'
    call emit 'P n='n 'T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'PSW='m~cpu~psw~rawHex 'R6='d2x(m~cpu~gpr(6),8) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record 'OUT='con~outputRecordCount 'IN='con~pendingInputCount 'ST='st||extra
  end
  /* An empty 3215 Read Inquiry is the expected interactive frontier. */
  if m~channels~hasActiveProgram(x2d('001F')) then do
    p=m~channels~activeProgram(x2d('001F'))
    ca=p~currentCCWAddress
    ccw=m~storage~fetchHex(ca,8)
    if ccw~left(2)='0A' & con~pendingInputCount=0 then do
      call emit '3215_READ_PENDING n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'CCW='d2x(ca,6)':'ccw 'PSW='m~cpu~psw~rawHex
      leave
    end
  end
  if st<>"OK" & st<>"WAIT" then do
    call emit 'STOP n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'OP='d2x(m~executor~lastOpcode,2) 'INST='m~executor~lastInstruction 'PSW='m~cpu~psw~rawHex
    leave
  end
  /* A non-interactive WAIT with no active console is evidence worth stopping on. */
  if st='WAIT' & \m~channels~hasActiveProgram(x2d('001F')) then do
    call emit 'WAIT_NO_CONSOLE_IO n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'PSW='m~cpu~psw~rawHex
    leave
  end
end
call emit 'END n='n 'T='format(time('E'),,3) 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'PSW='m~cpu~psw~rawHex 'OUT='con~outputRecordCount 'ST='st
call lineout log
exit 0

joinDevices:
  use strict arg a
  s=''
  do v over a
    if s<>'' then s||=','
    s||=d2x(v,4)
  end
  return s

emit:
  parse arg line
  call lineout log,line
  call lineout log
return

::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
