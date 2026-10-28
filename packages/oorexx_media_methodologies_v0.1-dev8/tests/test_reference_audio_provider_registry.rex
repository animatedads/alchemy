#!/usr/bin/env rexx
registry=.MediaReferenceAudioProviderRegistry~new('/tmp/providers')
call assertEq 5,registry~profiles~items,'five plural audio profiles'
call assertTrue registry~supports('AUDIO.DENOISE.SPECTRAL_SUBTRACTION'),'spectral subtraction supported'
call assertTrue registry~supports('AUDIO.DENOISE.WIENER'),'Wiener supported'
call assertTrue registry~supports('AUDIO.DENOISE.NMF'),'NMF supported'
call assertTrue registry~supports('AUDIO.HARMONIC_PERCUSSIVE'),'HPSS supported'
call assertTrue registry~supports('AUDIO.SPECTRAL.REPAIR'),'spectral repair supported'
cmd=registry~command('AUDIO.DENOISE.NMF','job.json','result.json')
call assertTrue pos('reference_audio_reconstruction.py',cmd)>0,'provider command names adapter'
say 'PASS plural reference audio provider registry'
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
::requires 'MediaReferenceAudioProviders.cls'
