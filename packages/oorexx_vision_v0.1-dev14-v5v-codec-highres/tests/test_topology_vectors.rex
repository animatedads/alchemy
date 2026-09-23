#!/usr/bin/env rexx
numeric digits 50
pts=.array~of(.array~of(0,0),.array~of(1,0),.array~of(2,0),.array~of(2,1))
path=.VisionContinuityPath~new(pts,5,.8,.7,.false)
v=.VisionPathVectorizer~new~vectorize(path)
call assert v~runs~items=2,"straight segments collapse into runs"
call assert v~runs[1]~direction="E" & v~runs[1]~runLength=2,"east run"
call assert v~runs[2]~direction="S","south run"

closedPts=.array~of(.array~of(0,0),.array~of(1,0),.array~of(1,1),.array~of(0,0))
closed=.VisionContourDetector~new~promote(.VisionContinuityPath~new(closedPts),.01)
call assert closed<>.nil & closed~closed,"explicit closed contour"

p1=.VisionContinuityPath~new(.array~of(.array~of(0,0),.array~of(1,1)))
p2=.VisionContinuityPath~new(.array~of(.array~of(0,0),.array~of(-1,1)))
p3=.VisionContinuityPath~new(.array~of(.array~of(0,0),.array~of(0,-1)))
js=.VisionTopologyAnalyzer~new~junctions(.array~of(p1,p2,p3))
call assert js~items=1 & js[1]~degree=3,"three-path junction"
say "PASS vision/0.1 dev7 vectors + contours + junctions"
exit 0
assert:
 use arg c,m
 if \c then do;say "FAIL:" m;exit 1;end
 return
::requires "../src/Vision.cls"
