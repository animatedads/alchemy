floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('corridor',.array~of(.array~of(0,0),.array~of(2,0),.array~of(2,3),.array~of(0,3))))
solver=.VisionPoseCloudSolver~new
seedA=solver~seedFromPoses('A',0,0,.array~of(.VisionCameraPoseCandidate~new('A',0,0,1,.5,90,1)),20)
constraintsA=.array~new
do i=1 to 8
  constraintsA~append(.VisionCameraStepConstraint~new('A',i,i/30,.03,.07,.05,-2,2,0,-10,10,0,.9,'native'))
end
eval=.VisionLayoutHypothesisEvaluator~new~evaluate(seedA,constraintsA,floor,.VisionCameraMotionPolicy~new(3,360),.VisionPoseCloudConfig~new(3,3,3,60))
if \eval~valid then do; say 'FAIL valid corridor died' eval~failedFrameIndex; exit 1; end
if eval~timeline~frames~items<>9 then do; say 'FAIL timeline length'; exit 1; end
say 'PASS layout hypothesis evaluator minSurvivors=' eval~minimumSurvivors
::requires 'Vision3DNativeMotion.cls'
