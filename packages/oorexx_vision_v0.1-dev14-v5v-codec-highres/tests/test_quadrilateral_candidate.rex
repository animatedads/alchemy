#!/usr/bin/env rexx
numeric digits 50
pts=.array~of(.array~of(0,0),.array~of(4,0),.array~of(4,3),.array~of(0,3),.array~of(0,0))
path=.VisionContinuityPath~new(pts,5,.9,.8,.true)
c=.VisionQuadrilateralDetector~new~candidates(.array~of(path),1,.5)
call assert c~items=1,"closed compact contour accepted"
call assert c[1]~bounds~width=4 & c[1]~bounds~height=3,"stable bounds"
thin=.VisionContinuityPath~new(.array~of(.array~of(0,0),.array~of(10,0),.array~of(10,1),.array~of(0,1),.array~of(0,0)),5,.9,.8,.true)
call assert .VisionQuadrilateralDetector~new~candidates(.array~of(thin),1,.5)~items=0,"thin contour rejected"
say "PASS vision/0.1 dev9 quadrilateral candidates"
exit 0
assert:
 use arg c,m
 if \c then do;say "FAIL:" m;exit 1;end
 return
::requires "../src/Vision.cls"
