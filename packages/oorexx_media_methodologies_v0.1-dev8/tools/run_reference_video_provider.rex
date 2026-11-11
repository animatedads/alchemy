/* Run registered video provider IN PROCESS through Alchemy Foreign Runtime.
 * Usage: rexx run_reference_video_provider.rex JOB.json RESULT.json PROVIDER_DIR
 *
 * Provider needs OpenCV/NumPy installed in the Python environment embedded by
 * Foreign Runtime.  No Python executable is launched, and source-derived
 * results must stay outside GitHub in the caller's controlled private store.
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
if \registry~supports(methodologyId) then do
  say "unregistered video reconstruction method"
  exit 65
end
invoker=.MediaForeignVideoInvoker~new(providerDir)
providerRc=invoker~run(methodologyId,jobPath,resultPath)
if providerRc<>0 then do
  say "foreign provider failed rc="providerRc
  exit providerRc
end
providerData=.json~fromJsonFile(resultPath)
if translate(strip(providerData["methodology_id"]))<>translate(strip(methodologyId)) then do
  say "foreign provider method mismatch"
  exit 66
end
if providerData["status"]<>"CANDIDATE" & providerData["status"]<>"NOT_APPLICABLE" then do
  say "foreign provider did not produce a valid status"
  exit 67
end
say "status="providerData["status"]
say "methodology="providerData["methodology_id"]
if providerData["implementation_id"]<>.nil then say "implementation="providerData["implementation_id"]
exit 0

::requires "json.cls"
::requires "MediaReferenceVideoProviders.cls"
::requires "MediaForeignVideoInvoker.cls"
