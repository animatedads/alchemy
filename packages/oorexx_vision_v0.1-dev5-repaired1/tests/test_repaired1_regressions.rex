#!/usr/bin/env rexx
numeric digits 50

/* Reserved RESULT regression: collection accumulators must remain arrays. */
a=.VisionSurface~new(8,6,5,26); b=.VisionSurface~new(8,6,5,26)
do y=2 to 4
  do x=1 to 3
    b~put(x,y,12)
  end
end
d=.VisionSurfaceDelta~new(a,b)
det=.VisionAreaOfInterestDetector~new
areas=det~fromDelta(d,4,17)
call assert areas~items=1, "AOI accumulator survives append"
area=areas[1]
req=area~request("storage:raw-video",8,256,"SOURCE")
call assert req~sourceRef="storage:raw-video", "AOI source preserved"
call assert req~startTime=4 & req~endTime=17, "AOI time range preserved"
call assert req~requestedBits=8 & req~requestedValueCount=256, "AOI fidelity preserved"
call assert req~requestedSpatialResolution="SOURCE", "AOI spatial fidelity preserved"

/* Non-short-circuit nil regressions in optimiser and persistence. */
coarse=.VisionSamplingLattice~new("RECT",2,0,0,2)
fine=.VisionSamplingLattice~new("RECT",1,0,0,1)
domain=.VisionRegion~new(0,0,4,4)
seq=.VisionPhaseSequence~new
seq~seed(coarse,2,2)
p=seq~next(fine,4,4,domain,2,4)
call assert p~uncoveredRadiusSquared>=0, "coverage optimiser initializes best safely"

tr=.VisionTrackTransform~new("actor-1",10,10)
r=.VisionRegion~new(10,10,1,1)
o=.VisionTrackObservation~new("actor-1",r,5,.9,tr)
acc=.VisionTrackEvidenceAccumulator~new("actor-1")
added=acc~addObservation(o,fine,20,20)
aged=acc~ageAt(8)
call assert aged~items=1 & aged[1]~age=3, "age accumulator survives append"

pr=.VisionPersistentRegion~new("actor-1")
pr~observe(o)
pr~observe(.VisionTrackObservation~new("actor-1",r,8,.7,tr))
call assert pr~firstTimestamp=5 & pr~lastTimestamp=8 & pr~duration=3, "persistence nil initialization safe"

say "PASS vision/0.1 dev5 repaired1 regressions"
exit 0

assert:
  use arg condition,message
  if \condition then do
    say "FAIL:" message
    exit 1
  end
  return

::requires "../src/Vision.cls"
