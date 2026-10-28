#!/usr/bin/env rexx
r=.MediaSpectralIntegrityProviderRegistry~new('/tmp/providers')
call assertEq 5,r~profiles~items,'five profiles'
call assertTrue r~supports('AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS'),'complementary supported'
call assertTrue r~supports('AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP'),'phase supported'
call assertTrue r~supports('AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW'),'preference supported'
call assertTrue r~supports('AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION'),'harmonic supported'
call assertTrue r~supports('QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL'),'control supported'
cmd=r~command('AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP','job.json','result.json','/tmp/upstream')
call assertTrue pos('spectral_integrity_provider.py',cmd)>0,'adapter command'
call assertTrue pos('--upstream-root',cmd)>0,'upstream is explicit'
attrs=.Directory~new
attrs['SOURCE_AUDIO_AVAILABLE']=.true
ctx=.MediaMethodologyIntentionContext~new('AUDIO','ANALYSIS',.nil,.nil,.nil,attrs)
c=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(c)
a=.MediaSpectralIntegrityApplicabilityProvider~new~assess(c~methodology('AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION'),.nil,ctx)
call assertEq 'UNKNOWN',a~state,'harmonic needs external f0'
attrs['EXTERNAL_F0_AVAILABLE']=.true
a=.MediaSpectralIntegrityApplicabilityProvider~new~assess(c~methodology('AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION'),.nil,ctx)
call assertEq 'APPLICABLE',a~state,'harmonic applicable with external f0'
say 'PASS spectral-integrity provider registry and applicability'
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
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaMethodologyIntentions.cls'
::requires 'MediaSpectralIntegrityProviders.cls'
