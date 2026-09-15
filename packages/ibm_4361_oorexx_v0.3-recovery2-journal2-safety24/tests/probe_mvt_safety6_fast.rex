numeric digits 30
parse arg mediaPath
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
st=m~runTicks(285000)
say 'ST='st 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'LASTIA='d2x(m~executor~lastIA,6) 'INST='m~executor~lastInstruction 'OUT='con~outputRecordCount
if st='UNSUPPORTED' then exit 0
exit 2
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
