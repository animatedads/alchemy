a=.VisionPoseCloudFrame~new('A',100,3.333)
b=.VisionPoseCloudFrame~new('B',78,3.334)
a~addCandidate(.VisionPoseCloudCandidate~new(.VisionCameraPoseCandidate~new('A',100,3.333,1.0,2.0,90,.9),5))
a~addCandidate(.VisionPoseCloudCandidate~new(.VisionCameraPoseCandidate~new('A',100,3.333,8.0,8.0,0,.4),1))
b~addCandidate(.VisionPoseCloudCandidate~new(.VisionCameraPoseCandidate~new('B',78,3.334,1.6,2.1,94,.9),5))
b~addCandidate(.VisionPoseCloudCandidate~new(.VisionCameraPoseCandidate~new('B',78,3.334,20,20,180,.5),1))

pairs=.VisionCrossSourcePoseMatcher~new~match(a,b,1.5,20,20)
if pairs~items<>1 then do; say 'FAIL expected one fuzzy common pair, got' pairs~items; exit 1; end
if pairs[1]~separationM>=1 then do; say 'FAIL separation'; exit 1; end
r=.VisionCommonLayoutFeasibility~new~checkSynchronizedClouds(a,b,1.5,20)
if \r~valid then do; say 'FAIL common layout'; exit 1; end
say 'PASS cross-source pose matcher separation=' pairs[1]~separationM 'headingDiff=' pairs[1]~headingDifferenceDeg
::requires 'Vision3DPoseCloud.cls'
