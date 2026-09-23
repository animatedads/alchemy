#!/usr/bin/env rexx
numeric digits 50
p=.FCVisionProjection~fromFiles('fixtures/fc_move1.events.tsv','fixtures/fc_move1.samples.tsv')
call assert p~items=1,'one admitted FC event projects to one Vision track'
t=p[1]
call assert t~trackRef='FCM00001','trackRef preserves local FC event identity'
call assert t~classification='CAR_MOTION','source observational class retained as metadata'
call assert t~observationCount=3,'three FC motion samples become observations'
call assert t~persistent~observationCount=3,'persistent region sees three observations'
call assert t~persistent~duration=1080,'persistence uses observation timestamps, not fabricated simultaneity'
call assert t~evidenceSampleCount>0,'track accumulator contains lattice evidence'
obs=t~accumulator~observations
canonical=.array~of(t~canonicalX,t~canonicalY)
do o over obs
  /* Every moving centroid maps to one canonical track coordinate. */
  s=o~evidence
  mapped=o~transform~worldToTrack(.array~of(s['centroid_x']+0,s['centroid_y']+0))
  call assert abs(mapped[1]-canonical[1])<0.0000001 & abs(mapped[2]-canonical[2])<0.0000001,'centroid stabilized in TRACK coordinates'
end
call assert t~accumulator~samples[1]~coordinateSpace='TRACK','accumulated evidence explicitly TRACK-space'
say 'PASS FC -> Vision projection assertions=10+'
exit 0
assert: procedure
  use arg c,m
  if \c then do
    say 'FAIL:' m
    exit 1
  end
  return
::requires '../src/FCVisionProjection.cls'
