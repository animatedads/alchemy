poses=.array~new
/* 90 degrees over half a second: 6 deg per native 30fps frame. */
do i=0 to 15
  poses~append(.VisionCameraPoseCandidate~new('A',i,i/30,0,0,i*6))
end
check=.VisionCameraTurnWindowFeasibility~new~checkPoses(poses)
if \check~valid then do; say 'FAIL 90deg/0.5s rejected'; do f over check~findings; say f; end; exit 1; end

bad=.array~new
/* 90 degrees inside 0.2 s exceeds the 72 degree six-frame window. */
do i=0 to 6
  bad~append(.VisionCameraPoseCandidate~new('A',i,i/30,0,0,i*15))
end
check=.VisionCameraTurnWindowFeasibility~new~checkPoses(bad)
if check~valid then do; say 'FAIL turn-window excess accepted'; exit 1; end
say 'PASS turn window feasibility maxGood=' .VisionCameraTurnWindowFeasibility~new~checkPoses(poses)~maxObservedAbsTurnDeg
::requires 'Vision3DPoseCloud.cls'
