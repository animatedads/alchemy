numeric digits 30
parse arg image maxTicks
if image="" then image="/mnt/data/mvt_media/mvtres.350"
if maxTicks="" then maxTicks=500000
media=.IBM370CCKDMedia~new(image,"MVTRES","DEV")
m=.IBM4361Machine~new(16777216)
m~powerOn
m~attachDevice(.IBM3330Device~new(x2d("350"),media))
m~initialProgramLoad(x2d("350"))
say "IPL phase="m~machinePhase "PSW="m~cpu~psw~rawHex "IA="d2x(m~cpu~psw~instructionAddress,6) "LOW2="m~storage~fetchHex(2,2)
do n=1 to maxTicks
  beforeIA=m~cpu~psw~instructionAddress
  beforeInst=m~storage~fetchHex(beforeIA,6)
  st=m~tick
  if m~cpu~instructionCount>=229360 then say "TRACE tick="n "IC="m~cpu~instructionCount "IA="d2x(beforeIA,6) "INST="beforeInst "CC="m~cpu~psw~conditionCode "NEXT="d2x(m~cpu~psw~instructionAddress,6) "ST="st
  if n//10000=0 then do
    dev=m~channels~device(x2d("350"))
    say "P" n "IC="m~cpu~instructionCount "IA="d2x(m~cpu~psw~instructionAddress,6) "CC="m~cpu~psw~conditionCode "CCHHR="dev~cylinder"/"dev~head"/"dev~record "ACTIVE="m~channels~hasActiveProgram(x2d("350")) "DONE="m~channels~completedStatusCount
  end
  if st<>"OK" then do
    dev=m~channels~device(x2d("350"))
    say "STOP status="st "ticks="n "IC="m~cpu~instructionCount "IA="d2x(m~cpu~psw~instructionAddress,6) "OP="d2x(m~executor~lastOpcode,2) "INST="m~executor~lastInstruction "PSW="m~cpu~psw~rawHex "CCHHR="dev~cylinder"/"dev~head"/"dev~record
    say "MEM120="m~storage~fetchHex(x2d("120"),64)
    do rr=0 to 15; say "R"rr"="d2x(m~cpu~gpr(rr),8); end
    leave
  end
end
exit 0
::requires "IBM4361.cls"
::requires "IBM370DASD.cls"
