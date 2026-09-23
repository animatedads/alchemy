floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('room',.array~of(.array~of(0,0),.array~of(4,0),.array~of(4,4),.array~of(0,4))))
solver=.VisionPoseCloudSolver~new
seedA=solver~seedFromPoses('A',0,0,.array~of(.VisionCameraPoseCandidate~new('A',0,0,1,1,90,1)),20)
seedB=solver~seedFromPoses('B',0,0,.array~of(.VisionCameraPoseCandidate~new('B',0,0,1.5,1,90,1)),20)
ca=.array~new; cb=.array~new
do i=1 to 6
  ca~append(.VisionCameraStepConstraint~new('A',i,i/30,.03,.06,.05,-2,2,0,-8,8,0,.9,'a'))
  cb~append(.VisionCameraStepConstraint~new('B',i,i/30,.03,.06,.05,-2,2,0,-8,8,0,.9,'b'))
end
e=.VisionLayoutHypothesisEvaluator~new
config=.VisionPoseCloudConfig~new(2,2,2,40)
policy=.VisionCameraMotionPolicy~new(3,360)
ea=e~evaluate(seedA,ca,floor,policy,config)
eb=e~evaluate(seedB,cb,floor,policy,config)
j=.VisionDualSourceLayoutEvaluator~new~evaluate(ea,eb,0,1.5,20)
if \j~valid then do; say 'FAIL no common dual-source layout'; exit 1; end
if j~commonFrames<7 then do; say 'FAIL common frame count' j~commonFrames; exit 1; end
say 'PASS dual-source layout evaluator frames=' j~commonFrames 'minPairs=' j~minimumPairCount
::requires 'Vision3DNativeMotion.cls'
