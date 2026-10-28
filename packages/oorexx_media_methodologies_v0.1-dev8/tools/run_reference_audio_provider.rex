#!/usr/bin/env rexx
use arg methodologyId,jobPath,resultPath,providerRoot
if methodologyId="" | jobPath="" | resultPath="" then do
  say "usage: run_reference_audio_provider.rex METHODOLOGY JOB_JSON RESULT_JSON [PROVIDER_ROOT]"
  exit 64
end
if providerRoot="" then providerRoot="providers"
registry=.MediaReferenceAudioProviderRegistry~new(providerRoot)
if \registry~supports(methodologyId) then do
  say "unsupported methodology:" methodologyId
  exit 65
end
address system registry~command(methodologyId,jobPath,resultPath)
exit rc
::requires "MediaMethodologyExecution.cls"
::requires "MediaReferenceAudioProviders.cls"
