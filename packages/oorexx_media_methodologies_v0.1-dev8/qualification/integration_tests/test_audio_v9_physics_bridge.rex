#!/usr/bin/env rexx
p=.AudioV9MultipathSpectralTrackPoint~new('FD',7,1000,14.25,-2.5,.91,.3,.9,'USEFUL_COHERENT_REFLECTION','SLOW_GEOMETRY_DRIFT',10,.7,.8,.6,.9,.92,.88,.333,.381,.286,.97,'STABLE_TRANSFER')
e=.MediaAudioV9PhysicsBridge~new~assess(p,120,'sha256:source')
call assertEq 'AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY',e~methodologyId,'methodology id'
call assertEq 'MEASURE',e~authorityEffect,'measurement authority'
call assertEq 'NOT_PRODUCED',e~metadata['SOURCE_RANGE_PROBABILITY'],'no source range probability'
call assertEq 'NOT_PRODUCED',e~metadata['REFLECTOR_VELOCITY'],'no reflector velocity promotion'
call assertTrue e~metadata['OVERALL_FIT']>.8,'stable path compatibility retained'
say 'PASS Audio V9 physics compatibility bridge'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::requires 'MediaAudioV9PhysicsBridge.cls'
