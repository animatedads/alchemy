#!/usr/bin/env rexx
parse arg methodologyId jobPath resultPath upstreamRoot providerRoot
if methodologyId="" | jobPath="" | resultPath="" | upstreamRoot="" then do
  say "usage: run_spectral_integrity_provider.rex METHODOLOGY JOB_JSON RESULT_JSON UPSTREAM_ROOT [PROVIDER_ROOT]"
  exit 64
end
if providerRoot="" then providerRoot="providers"
registry=.MediaSpectralIntegrityProviderRegistry~new(providerRoot)
if \registry~supports(methodologyId) then do
  say "unsupported methodology:" methodologyId
  exit 65
end
address system registry~command(methodologyId,jobPath,resultPath,upstreamRoot)
exit rc
::requires "MediaMethodologyExecution.cls"
::requires "MediaSpectralIntegrityProviders.cls"
