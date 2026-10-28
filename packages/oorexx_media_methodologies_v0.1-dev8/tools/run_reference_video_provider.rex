/* Execute one explicit reference provider job.
 * Usage: rexx run_reference_video_provider.rex JOB.json RESULT.json PROVIDER_DIR
 */
parse arg jobPath resultPath providerDir
if strip(jobPath)="" | strip(resultPath)="" | strip(providerDir)="" then do
  say "usage: run_reference_video_provider.rex JOB.json RESULT.json PROVIDER_DIR"
  exit 64
end
jobData=.json~fromJsonFile(jobPath)
methodologyId=jobData["methodology_id"]
if methodologyId=.nil then do
  say "job has no methodology_id"
  exit 65
end
registry=.MediaReferenceVideoProviderRegistry~new(providerDir)
commandText=registry~command(methodologyId,jobPath,resultPath)
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
::requires "MediaReferenceVideoProviders.cls"
