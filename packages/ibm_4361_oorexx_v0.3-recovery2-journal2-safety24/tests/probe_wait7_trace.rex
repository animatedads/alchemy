numeric digits 30
log='/mnt/data/wait7_trace.log'; call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV'); dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 101000
 ia=m~cpu~psw~instructionAddress
 inst=m~storage~fetchHex(ia,6)
 op=inst~left(2)
 if n>=100450 then do
   line='PRE n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='inst 'CC='m~cpu~psw~conditionCode 'R1='d2x(m~cpu~gpr(1),8) 'R2='d2x(m~cpu~gpr(2),8) 'R12='d2x(m~cpu~gpr(12),8) 'R15='d2x(m~cpu~gpr(15),8)
   call emit line
 end
 if op='82' then do
   b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3)); ea=d; if b<>0 then ea=ea+m~cpu~gpr(b); ea=ea//16777216
   call emit 'LPSW n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'EA='d2x(ea,6) 'OPERAND='m~storage~fetchHex(ea,8)
 end
 st=m~tick
 if st<>"OK" then do
   call emit 'STOP n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'PSW='m~cpu~psw~rawHex 'LASTOP='d2x(m~executor~lastOpcode,2) 'LASTINST='m~executor~lastInstruction 'ST='st
   call emit 'LOW000='m~storage~fetchHex(0,128)
   call emit 'LOW040='m~storage~fetchHex(x2d('40'),32)
   call emit 'DEV CCHHR='dev~cylinder'/'dev~head'/'dev~record 'SENSE='dev~pendingSenseHex 'ACTIVE='m~channels~hasActiveProgram(x2d('350')) 'DONE='m~channels~completedStatusCount 'PENDING='m~channels~pendingInterruptCount
   do r=0 to 15; call emit 'R'r'='d2x(m~cpu~gpr(r),8); end
   leave
 end
end
call emit 'END n='n 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'ST='st
call lineout log
exit 0
emit: parse arg line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
