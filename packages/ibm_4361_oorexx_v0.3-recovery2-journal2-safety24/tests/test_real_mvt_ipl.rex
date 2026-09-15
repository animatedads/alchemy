parse arg path digest
if path="" then do
  say 'SKIP test_real_mvt_ipl (set MVTRES_350 or pass path)'
  exit 0
end
if digest="" then digest="UNVERIFIED"
media=.IBM370CCKDMedia~new(path,"MVTRES",digest)
dev=.IBM3330Device~new(x2d("0350"),media)
m=.IBM4361Machine~new(16*1024*1024)
m~powerOn
m~attachDevice(dev)
m~initialProgramLoad(x2d("0350"))
if m~machinePhase<>"GUEST_STARTED" then raise syntax 40.900 array('real MVT IPL did not start guest',m~machinePhase)
if m~cpu~psw~rawHex<>"0000000000000080" then raise syntax 40.900 array('unexpected real MVT IPL PSW',m~cpu~psw~rawHex)
if m~cpu~psw~instructionAddress<>x2d("80") then raise syntax 40.900 array('unexpected real MVT IPL IA',m~cpu~psw~instructionAddress)
say 'PASS test_real_mvt_ipl PSW='m~cpu~psw~rawHex 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
::requires "IBM4361.cls"
::requires "IBM370DASD.cls"
