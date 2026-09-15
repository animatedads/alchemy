numeric digits 30
image="/mnt/data/mvt_media/mvtres.350"
media=.IBM370CCKDMedia~new(image,"MVTRES","DEV")
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(.IBM3330Device~new(x2d("350"),media)); m~initialProgramLoad(x2d("350"))
do n=1 to 10000
  st=m~tick
  if n//100=0 | st<>"OK" then do
    dev=m~channels~device(x2d("350")); ap="-"; cmd="-"
    if m~channels~hasActiveProgram(x2d("350")) then do; p=m~channels~activeProgram(x2d("350")); ap=d2x(p~currentCCWAddress,6); cmd=d2x(p~lastCommand,2); end
    say "P" n "IC="m~cpu~instructionCount "IA="d2x(m~cpu~psw~instructionAddress,6) "CC="m~cpu~psw~conditionCode "CCHHR="dev~cylinder"/"dev~head"/"dev~record "AP="ap "LASTCMD="cmd "DONE="m~channels~completedStatusCount "ST="st
  end
  if st<>"OK" then leave
end
exit 0
::requires "IBM4361.cls"
::requires "IBM370DASD.cls"
