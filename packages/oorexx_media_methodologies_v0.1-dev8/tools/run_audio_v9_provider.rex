/* Execute one explicit Audio V9 methodology provider job.
 * Usage: rexx run_audio_v9_provider.rex JOB.json RESULT.json PROVIDER_DIR AUDIO_V9_ROOT
 */
parse arg jobPath resultPath providerDir audioV9Root
if strip(jobPath)="" | strip(resultPath)="" | strip(providerDir)="" | strip(audioV9Root)="" then do
  say "usage: run_audio_v9_provider.rex JOB.json RESULT.json PROVIDER_DIR AUDIO_V9_ROOT"
  exit 64
end
jobData=.json~fromJsonFile(jobPath)
methodologyId=jobData["methodology_id"]
if methodologyId=.nil then do
  say "job has no methodology_id"
  exit 65
end
registry=.MediaAudioV9ProviderRegistry~new(providerDir)
commandText=registry~command(methodologyId,jobPath,resultPath,audioV9Root)
address system commandText
providerRc=rc
if providerRc<>0 then do
  say "provider failed rc="providerRc
  exit providerRc
end
providerData=.json~fromJsonFile(resultPath)
say "status="providerData["status"]
say "methodology="providerData["methodology_id"]
if providerData["implementation_id"]<>.nil then say "implementation="providerData["implementation_id"]
exit 0

::requires "json.cls"
::requires "MediaAudioV9Providers.cls"
