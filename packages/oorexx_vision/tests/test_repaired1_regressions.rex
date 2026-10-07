#!/usr/bin/env rexx
numeric digits 50

/* Reserved RESULT regressions: collection accumulators must remain arrays. */
a=.VisionSurface~new(8,6,5,26); b=.VisionSurface~new(8,6,5,26)
do y=2 to 4
  do x=1 to 3
    b~put(x,y,12)
  end
end
d=.VisionSurfaceDelta~new(a,b)
areas=.VisionAreaOfInterestDetector~new~fromDelta(d,4,17)
call assert areas~items=1,"AOI accumulator survives append"
req=areas[1]~request("storage:raw-video",8,256,"SOURCE")
call assert req~sourceRef="storage:raw-video","AOI source preserved"
call assert \(req~startTime<>4 | req~endTime<>17),"AOI time range preserved"
call assert \(req~requestedBits<>8 | req~requestedValueCount<>256),"AOI fidelity preserved"
call assert req~requestedSpatialResolution="SOURCE","AOI spatial fidelity preserved"

lib=.VisionCurveLibrary~new
model=.VisionPaletteSelector~new(lib,0,0,0)~colourModel
surf=.VisionSurface~new(4,4,5,26,model)
do y=0 to 3
  do x=2 to 3; surf~put(x,y,25); end
end
boundaries=.VisionBoundaryExtractor~new~extract(surf,10)
call assert boundaries~isA(.array),"boundary accumulator is array"
call assert boundaries~items>0,"boundary accumulator survives append"

/* Non-short-circuit nil regressions in optimiser and persistence. */
coarse=.VisionSamplingLattice~new("RECT",2,0,0,2)
fine=.VisionSamplingLattice~new("RECT",1,0,0,1)
domain=.VisionRegion~new(0,0,4,4)
seq=.VisionPhaseSequence~new
seq~seed(coarse,2,2)
p=seq~next(fine,4,4,domain,2,4)
call assert p~uncoveredRadiusSquared>=0,"coverage optimiser initializes best safely"

tr=.VisionTrackTransform~new("actor-1",10,10)
r=.VisionRegion~new(10,10,1,1)
o=.VisionTrackObservation~new("actor-1",r,5,.9,tr)
acc=.VisionTrackEvidenceAccumulator~new("actor-1")
call assert acc~addObservation(o,fine,20,20)=1,"track sample added"
aged=acc~ageAt(8)
call assert aged~items=1,"age accumulator count"
call assert aged[1]~age=3,"age accumulator survives append"

pr=.VisionPersistentRegion~new("actor-1")
pr~observe(o)
pr~observe(.VisionTrackObservation~new("actor-1",r,8,.7,tr))
call assert \(pr~firstTimestamp<>5 | pr~lastTimestamp<>8 | pr~duration<>3),"persistence nil initialization safe"

/* Geometry length uses the package-local portable sqrt helper. */
path=.VisionContinuityPath~new(.array~of(.array~of(0,0),.array~of(3,4)))
call assert abs(path~length-5)<0.000000001,"3-4-5 path length"

/* Nil contour is tested before any contour method is sent. */
open=.VisionContinuityPath~new(.array~of(.array~of(0,0),.array~of(1,0),.array~of(2,0)))
call assert .VisionQuadrilateralDetector~new~candidates(.array~of(open),1,.5)~items=0,"open path safely rejected"

/* Evidence escalation populates the four-argument RegionRequest contract. */
m=.VisionGeometryMeasurement~new(10,"A",1,1,1,0,0,1,1)
policy=.VisionEvidenceEscalationPolicy~new(2,0,0,0)
er=policy~request(m,"storage:source",.VisionRegion~new(0,0,4,4),10,11,"640x360",8,256,"LINE")
call assert er<>.nil,"refinement requested"
call assert \(er~startTime<>10 | er~endTime<>11),"refinement time range"
call assert \(er~requestedSpatialResolution<>"640x360" | er~requestedBits<>8 | er~requestedValueCount<>256),"refinement fidelity"
call assert er~purpose="LINE","refinement purpose"

/* Dev15 V5V first record must not rely on boolean short-circuit semantics. */
v=.VisionSurface~new(2,2,5,26); v~timestamp=1
codec=.V5VTemporalCodec~new
record=codec~encodeSurface(v)
call assert record~recordType="KEYFRAME","first V5V record is keyframe"

/* High-resolution request lifecycle is explicit and one-way. */
hr=.VisionHighResolutionRequest~new("storage:source",.VisionRegion~new(1,2,3,4),10,11,"LINE")
hr~requireDimensions(640,360)
hr~markFulfilled("storage:material")
call assert \(hr~state<>"FULFILLED" | hr~asRegionRequest~resultRef<>"storage:material"),"high-resolution lifecycle"

say "PASS vision/0.1 dev15 repaired1 regressions"
exit 0

assert: procedure
  use arg condition,message
  if \condition then do
    say "FAIL:" message
    exit 1
  end
  return

::requires "../src/VisionHighResolutionRequest.cls"
::requires "../src/V5VCodec.cls"
