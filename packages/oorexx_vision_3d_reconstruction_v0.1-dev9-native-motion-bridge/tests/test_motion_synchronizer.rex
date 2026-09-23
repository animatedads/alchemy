a=.VisionMotionSeries~new('A',30)
b=.VisionMotionSeries~new('B',30)
valsA=.array~of(9,8,1,3,2,7,4,6,5,0,2,8)
valsB=.array~of(1,3,2,7,4,6,5,0,2,8)
do i=1 to valsA~items; a~add(.VisionMotionSample~new((i-1)/30,valsA[i],1,i-1)); end
do i=1 to valsB~items; b~add(.VisionMotionSample~new((i-1)/30,valsB[i],1,i-1)); end
sync=.VisionMotionSynchronizer~new~bestLagFrames(a,b,4,8)
if sync==.nil then do; say 'FAIL no sync'; exit 1; end
if sync~lagFrames<>2 then do; say 'FAIL lag' sync~lagFrames; exit 1; end
if sync~correlation<.999 then do; say 'FAIL corr' sync~correlation; exit 1; end
if sync~overlap<>10 then do; say 'FAIL overlap' sync~overlap; exit 1; end
say 'PASS motion synchronizer lag='sync~lagFrames 'correlation='sync~correlation
::requires 'Vision3DCameraPath.cls'
