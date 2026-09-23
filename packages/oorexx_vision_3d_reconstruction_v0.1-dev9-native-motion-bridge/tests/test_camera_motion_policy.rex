policy=.VisionCameraMotionPolicy~new
if policy~maxSpeedMps<>3 then do; say 'FAIL max speed'; exit 1; end
if policy~maxAngularRateDps<>360 then do; say 'FAIL max angular rate'; exit 1; end

floor=.VisionAccessibleFloor~new
floor~addRegion(.VisionFloorPolygon~new('hall',.array~of(.array~of(0,0),.array~of(1,0),.array~of(1,4),.array~of(0,4))))
floor~addWall(.VisionWallSegment~new('wall-right',1,0,1,3))

check=.VisionCameraPathFeasibility~new
p1=.VisionCameraPoseCandidate~new('cam',0,0,0.5,0.5,0)
p2=.VisionCameraPoseCandidate~new('cam',15,.5,0.5,1.5,90)
r=check~checkTransition(p1,p2,floor,policy)
if \r~valid then do; say 'FAIL 90deg/0.5s should be valid'; exit 1; end
if abs(r~speedMps-2)>.0001 then do; say 'FAIL speed' r~speedMps; exit 1; end
if abs(r~angularRateDps-180)>.0001 then do; say 'FAIL angular' r~angularRateDps; exit 1; end

fast=.VisionCameraPoseCandidate~new('cam',1,1/30,0.7,0.5,0)
r=check~checkTransition(p1,fast,floor,policy)
if r~valid then do; say 'FAIL speed limit'; exit 1; end
if r~findings[1]~pos('SPEED_LIMIT:')<>1 then do; say 'FAIL speed finding'; exit 1; end

spin=.VisionCameraPoseCandidate~new('cam',1,1/30,0.5,0.5,20)
r=check~checkTransition(p1,spin,floor,policy)
if r~valid then do; say 'FAIL angular limit'; exit 1; end
if r~findings[1]~pos('ANGULAR_RATE_LIMIT:')<>1 then do; say 'FAIL angular finding'; exit 1; end

left=.VisionCameraPoseCandidate~new('cam',0,0,.5,2,0)
right=.VisionCameraPoseCandidate~new('cam',15,.5,1.5,2,0)
r=check~checkTransition(left,right,floor,policy)
if r~valid then do; say 'FAIL wall crossing'; exit 1; end
found=.false
do f over r~findings
  if f~pos('WALL_CROSSING:wall-right')=1 then found=.true
end
if \found then do; say 'FAIL wall finding'; exit 1; end
say 'PASS camera motion policy/path feasibility'
::requires 'Vision3DCameraPath.cls'
