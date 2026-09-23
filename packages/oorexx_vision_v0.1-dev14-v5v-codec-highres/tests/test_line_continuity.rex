#!/usr/bin/env rexx
numeric digits 50
lib=.VisionCurveLibrary~new
model=.VisionPaletteSelector~new(lib,0,0,0)~colourModel
surf=.VisionSurface~new(4,4,5,26,model)
do y=0 to 3
 do x=2 to 3
  surf~put(x,y,25)
 end
end
l=.VisionSamplingLattice~new("RECT",1,0,0,1)
edges=.VisionBoundaryExtractor~new~extract(surf,1)
call assert edges~items>0,"encoded surface yields boundaries"
paths=.VisionLineContinuity~new~extract(surf,l,1)
call assert paths~items>0,"boundaries yield continuity paths"
call assert paths[1]~points~items>0,"path has stable-coordinate points"
tr=.VisionTrackTransform~new("actor-L",1,0)
te=.VisionTrackContinuityEvidence~new("actor-L")
call assert te~add(paths[1],10,.9,tr)=1,"continuity accumulated in track space"
say "PASS vision/0.1 dev6 line continuity + track evidence"
exit 0
assert:
 use arg c,m
 if \c then do;say "FAIL:" m;exit 1;end
 return
::requires "../src/Vision.cls"
