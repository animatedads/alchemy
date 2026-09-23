floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('hall',.array~of(.array~of(0,0),.array~of(2,0),.array~of(2,5),.array~of(0,5))))
/* right wall split around doorway from y=3.0 to 3.9 */
floor~addWall(.VisionWallSegment~new('right-lower',2,0,2,3.0))
floor~addWall(.VisionWallSegment~new('right-upper',2,3.9,2,5))

solver=.VisionPoseCloudSolver~new
seedPoses=.array~new
seedPoses~append(.VisionCameraPoseCandidate~new('A',0,0,1,0.5,90,1,'seed'))
cloud=solver~seedFromPoses('A',0,0,seedPoses,20)
if cloud~items<>1 then do; say 'FAIL seed'; exit 1; end

/* 1/30 s, roughly 5 cm forward, no meaningful turn */
c=.VisionCameraStepConstraint~new('A',1,1/30,.03,.07,.05,-3,3,0,-8,8,0,.9,'motion')
next=solver~propagate(cloud,c,floor,.VisionCameraMotionPolicy~new,.VisionPoseCloudConfig~new(3,3,3,40))
if next~items=0 then do; say 'FAIL no survivors'; exit 1; end
best=next~best~pose
if best~y<=0.5 then do; say 'FAIL did not move forward' best~x best~y; exit 1; end
if best~y>0.61 then do; say 'FAIL moved too far' best~y; exit 1; end
say 'PASS pose cloud propagation survivors=' next~items 'best=' best~x best~y best~headingDeg
::requires 'Vision3DPoseCloud.cls'
