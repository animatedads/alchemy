#!/usr/bin/env rexx
catalogue=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalogue)
shapes=.MediaWorkShapeCatalogue~new
.MediaWorkShapeBuiltins~populate(shapes,catalogue)
call check catalogue,'AUDIO.MULTIPATH.PATH_ESTIMATE','MEASURE',.false
call check catalogue,'AUDIO.MULTIPATH.SPECTRAL_TRACK','MEASURE',.false
call check catalogue,'AUDIO.MULTIPATH.MOTION_COHERENCE','MEASURE',.false
call check catalogue,'AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY','MEASURE',.false
call check catalogue,'AUDIO.RECON.MULTIPATH_VIRTUAL_MIC','RECONSTRUCT',.true
coh=shapes~shape('AUDIO.MULTIPATH.MOTION_COHERENCE')
call assertEq 'ACCUMULATOR_STATE',coh~stateModel,'motion coherence continuation state'
call assertEq 'STATE_HANDOFF_REQUIRED',coh~continuity,'motion coherence state handoff required'
vm=shapes~shape('AUDIO.RECON.MULTIPATH_VIRTUAL_MIC')
call assertEq 'RECONSTRUCTION_SUPPORT_MERGE',vm~mergeMode,'virtual mic candidate merge semantics'
say 'PASS audio multipath catalogue and work-shape semantics'
exit 0
check: procedure
  use arg catalogue,id,authority,reconstructive
  m=catalogue~methodology(id)
  call assertTrue m<>.nil,id 'exists'
  call assertEq authority,m~authorityEffect,id 'authority'
  call assertEq reconstructive,m~reconstructive,id 'reconstructive flag'
  return
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
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaWorkShapeBuiltins.cls'
