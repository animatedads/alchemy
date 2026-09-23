/* exact four-point floor homography */
src=.array~of(.array~of(0,0),.array~of(2,0),.array~of(2,1),.array~of(0,1))
dst=.array~of(.array~of(10,20),.array~of(14,20),.array~of(14,23),.array~of(10,23))
h=.VisionFloorHomography~fromFourPairs(src,dst,'A','B','a0','b0')
p=h~project(.array~of(1,0.5))
call assertNear p[1],12,.000001,'project x'
call assertNear p[2],21.5,.000001,'project y'
say 'PASS floor homography'
exit 0
::routine assertNear
  use strict arg actual,expected,tol,label
  if abs(actual-expected)>tol then do; say 'FAIL' label actual expected; exit 1; end
::requires 'Vision3DStructure.cls'
