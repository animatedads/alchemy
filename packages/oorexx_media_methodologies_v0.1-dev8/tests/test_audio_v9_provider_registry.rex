#!/usr/bin/env rexx
registry=.MediaAudioV9ProviderRegistry~new('/tmp/providers')
call assertEq 5,registry~profiles~items,'five Audio V9 methodology profiles'
call assertTrue registry~supports('AUDIO.MULTIPATH.PATH_ESTIMATE'),'path estimator supported'
call assertTrue registry~supports('AUDIO.MULTIPATH.SPECTRAL_TRACK'),'spectral tracker supported'
call assertTrue registry~supports('AUDIO.MULTIPATH.MOTION_COHERENCE'),'motion coherence supported'
call assertTrue registry~supports('AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY'),'physics compatibility supported'
call assertTrue registry~supports('AUDIO.RECON.MULTIPATH_VIRTUAL_MIC'),'virtual mic supported'
p=registry~profile('AUDIO.MULTIPATH.MOTION_COHERENCE')
call assertEq 'CHECKPOINTED',p~recoveryClass,'continuation recovery class'
call assertTrue p~requiredAbilities~items>=2,'provider abilities retained'
cmd=registry~command('AUDIO.MULTIPATH.PATH_ESTIMATE','job.json','result.json','/audio-v9')
call assertTrue pos('audio_v9_reference_provider.py',cmd)>0,'provider command names adapter'
call assertTrue pos('--audio-v9-root',cmd)>0,'provider command preserves external Audio V9 root'
say 'PASS Audio V9 methodology provider registry'
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
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaAudioV9Providers.cls'
