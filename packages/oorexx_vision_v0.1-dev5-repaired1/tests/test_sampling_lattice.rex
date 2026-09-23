#!/usr/bin/env rexx
numeric digits 50
call testStableCoverage
call testComplementarySequence
call testTrackEvidence
say "PASS vision/0.1 dev4 stable lattice + minimax phases + temporal evidence"
exit 0

testStableCoverage:
  fine=.VisionSamplingLattice~new("HEX",1,0,.5,.86602540378443864676,0,0,.25,.25,32,1)
  region=.VisionRegion~new(0,0,2,2)
  q=.VisionRefinedRegion~new(region,fine,8,8)
  call assert q~samples~items>0, "coverage query returns lattice samples"
  first=q~samples[1]
  call assert first[3]>=region~x & first[3]<(region~x+region~width), "sample remains in stable coordinates"
  return

testComplementarySequence:
  coarse=.VisionSamplingLattice~new("HEX",2,0,1,1.73205080756887729352,0,0,0,0,8,1)
  fine=.VisionSamplingLattice~new("HEX",1,0,.5,.86602540378443864676,0,0,0,0,32,1)
  domain=.VisionRegion~new(0,0,8,6)
  seq=.VisionPhaseSequence~new
  seq~seed(coarse,4,3)
  a=seq~next(fine,8,6,domain,4,10)
  b=seq~next(fine,8,6,domain,4,10)
  call assert a~uncoveredRadiusSquared>=0 & b~uncoveredRadiusSquared>=0, "minimax scores valid"
  call assert b~uncoveredRadiusSquared<=a~uncoveredRadiusSquared, "accumulated coverage does not worsen"
  transform=.VisionSamplingTransform~new(coarse,fine,.array~of(a~u,a~v))
  parent=.VisionSurface~new(4,3,5,26)
  refined=.VisionSurface~new(8,6,5,26)
  key=.VisionKeyFrame~new(parent,refined,coarse,fine~withPhase(a~u,a~v),transform)
  call assert key~samplingTransform~coveragePolicy="MINIMAX-UNCOVERED-RADIUS", "keyframe carries sampling transform"
  return

testTrackEvidence:
  world=.VisionAccumulatedSample~new(.array~of(1,2),10,0,1,"WORLD")
  track=.VisionAccumulatedSample~new(.array~of(.2,.3),11,1,.8,"TRACK","actor-7")
  call assert world~coordinateSpace="WORLD", "static evidence world space"
  call assert track~coordinateSpace="TRACK" & track~trackRef="actor-7", "moving evidence track space"
  return

assert:
  use arg condition,message
  if \condition then do
    say "FAIL:" message
    exit 1
  end
  return

::requires "../src/Vision.cls"
