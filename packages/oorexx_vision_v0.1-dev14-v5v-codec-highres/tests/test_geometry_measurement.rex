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
m=.VisionGeometryMeter~new~measure(surf,l,10,"A",1)
call assert m~boundaryCount>0,"boundary metric"
call assert m~pathCount>0,"path metric"
call assert m~pathLength>=0,"length metric"
series=.VisionGeometrySeries~new("WORLD")
call assert series~add(m)=1,"series accumulation"
call assert series~latest~phaseId="A","phase retained"
policy=.VisionEvidenceEscalationPolicy~new(m~pathLength+1,0,0,0)
req=policy~request(m,"raw-source",.VisionRegion~new(0,0,4,4),10,11,32,8,256,"LINE-CONTINUITY")
call assert req<>.nil,"weak geometry requests ROI refinement"
policy2=.VisionEvidenceEscalationPolicy~new(0,0,0,0)
call assert policy2~request(m,"raw-source",.VisionRegion~new(0,0,4,4),10,11,32,8,256)=.nil,"adequate evidence avoids ROI"
say "PASS vision/0.1 dev8 geometry measurement + evidence escalation"
exit 0
assert:
 use arg c,m
 if \c then do;say "FAIL:" m;exit 1;end
 return
::requires "../src/Vision.cls"
