/* Real native-frame motion trace -> dev9 pose clouds.
 * The floor region below is deliberately broad qualification space, NOT an
 * inferred apartment layout.  This proves the recorded evidence drives the
 * same physical pose-cloud machinery without giving the solver the answer.
 */
parse arg traceFile
if traceFile='' then traceFile='DUAL_CAMERA_NATIVE_5BIT_TRACE.json'
root=.json~fromJsonFile(traceFile)
adapter=.VisionRecordedMotionTraceAdapter~new
limit=120
ca=adapter~constraintsFromVideoNode(root['video_A'],limit)
cb=adapter~constraintsFromVideoNode(root['video_B'],limit)

floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('qualification-open-space',.array~of(.array~of(0,0),.array~of(8,0),.array~of(8,8),.array~of(0,8))))
solver=.VisionPoseCloudSolver~new
seedA=solver~seedFromPoses('A',0,0,.array~of(.VisionCameraPoseCandidate~new('A',0,0,4,4,0,1,'TRACE_SEED')),40)
seedB=solver~seedFromPoses('B',0,0,.array~of(.VisionCameraPoseCandidate~new('B',0,0,4.5,4,0,1,'TRACE_SEED')),40)
config=.VisionPoseCloudConfig~new(2,1,1,12)
policy=.VisionCameraMotionPolicy~new(3,360)
evaluator=.VisionLayoutHypothesisEvaluator~new
ea=evaluator~evaluate(seedA,ca,floor,policy,config)
eb=evaluator~evaluate(seedB,cb,floor,policy,config)
lag=root['consensus_lag_frames_A_after_B']
joint=.VisionDualSourceLayoutEvaluator~new~evaluate(ea,eb,lag,2,60)
say 'A valid' ea~valid 'frames' ea~timeline~frames~items 'min survivors' ea~minimumSurvivors
say 'B valid' eb~valid 'frames' eb~timeline~frames~items 'min survivors' eb~minimumSurvivors
say 'joint valid' joint~valid 'common frames' joint~commonFrames 'min pairs' joint~minimumPairCount 'lag' lag
if \ea~valid | \eb~valid | \joint~valid then exit 1
say 'PASS real native-trace pose-cloud replay (qualification open space)'
::requires 'Vision3DNativeMotion.cls'
::requires 'json.cls'
