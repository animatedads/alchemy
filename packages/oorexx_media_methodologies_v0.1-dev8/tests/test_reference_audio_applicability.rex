#!/usr/bin/env rexx
catalogue=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalogue)
provider=.MediaReferenceAudioApplicabilityProvider~new
attrs=.Directory~new; attrs['SOURCE_AUDIO_AVAILABLE']=.true
ctx=.MediaMethodologyIntentionContext~new("","",.nil,.nil,.nil,attrs)
spec=catalogue~methodology('AUDIO.DENOISE.WIENER')
a=provider~assess(spec,.nil,ctx)
call assertEq 'APPLICABLE',a~state,'Wiener available with source audio'
spec=catalogue~methodology('AUDIO.SPECTRAL.REPAIR')
a=provider~assess(spec,.nil,ctx)
call assertEq 'UNKNOWN',a~state,'repair not assumed without damage mask'
attrs['AUDIO_DAMAGE_MASK_AVAILABLE']=.true
ctx=.MediaMethodologyIntentionContext~new("","",.nil,.nil,.nil,attrs)
a=provider~assess(spec,.nil,ctx)
call assertEq 'APPLICABLE',a~state,'repair available with explicit mask'
attrs=.Directory~new; ctx=.MediaMethodologyIntentionContext~new("","",.nil,.nil,.nil,attrs)
a=provider~assess(catalogue~methodology('AUDIO.DENOISE.NMF'),.nil,ctx)
call assertEq 'NOT_APPLICABLE',a~state,'no source means no reconstruction'
say 'PASS plural audio methodology applicability is dynamic and fail-closed'
exit 0
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyIntentions.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaReferenceAudioProviders.cls'
