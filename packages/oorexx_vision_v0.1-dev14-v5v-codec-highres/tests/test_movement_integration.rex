#!/usr/bin/env rexx
numeric digits 50
l=.VisionSamplingLattice~new("RECT",1,0,0,1)
r=.VisionRegion~new(10,10,3,3)
tr=.VisionTrackTransform~new("actor-1",10,10)
o=.VisionTrackObservation~new("actor-1",r,5,.9,tr)
a=.VisionTrackEvidenceAccumulator~new("actor-1")
call assert a~addObservation(o,l,20,20)=9,"nine track samples"
call assert a~samples[1]~coordinateSpace="TRACK","track coordinates"
call assert a~samples[1]~point[1]=0 & a~samples[1]~point[2]=0,"track origin"
call assert a~ageAt(8)[1]~age=3,"age retained"
pr=.VisionPersistentRegion~new("actor-1")
pr~observe(o); pr~observe(.VisionTrackObservation~new("actor-1",r,8,.7,tr))
call assert pr~observationCount=2 & pr~duration=3,"persistence"
assoc=.VisionRegionAssociation~new
call assert assoc~overlapRatio(.VisionRegion~new(0,0,4,4),.VisionRegion~new(2,0,4,4))>0,"association"
say "PASS vision/0.1 dev5 Movement track evidence"
exit 0
assert:
 use arg c,m
 if \c then do;say "FAIL:" m;exit 1;end
 return
::requires "../src/Vision.cls"
