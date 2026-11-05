/* Source-only embedded Foreign Runtime synthetic smoke.
 * The private-root gate must be satisfied even for a synthetic provider.
 * Set ALCHEMY_PRIVATE_MEDIA_ROOT to a pre-existing absolute NON-Git directory.
 * Neither the fixture nor these test outputs contain video-derived material.
 */
privateRoot=value('ALCHEMY_PRIVATE_MEDIA_ROOT',,'ENVIRONMENT')
if privateRoot='' then do
  say 'FAIL: ALCHEMY_PRIVATE_MEDIA_ROOT required for smoke test'
  exit 64
end
methodId='VIDEO.RECON.FLOW_WARP_ACCUMULATE'
providerRoot='tests/fixtures/foreign_runtime_video'
registry=.MediaReferenceVideoProviderRegistry~new(providerRoot)
if \registry~supports(methodId) then raise syntax 93.900 array('Unknown synthetic method')
invoker=.MediaForeignVideoInvoker~new(providerRoot)

/* Stage the WHOLLY SYNTHETIC job inside the designated private root.
 * The provider implementation remains trusted source inside Git checkout. */
fixture=providerRoot||'/job.json'
jobText=charin(fixture,1,chars(fixture))
call charin fixture
jobText=changestr('"/tmp"','"'||privateRoot||'"',jobText)
jobPath=privateRoot||'/eyepoke-foreign-job-synthetic.json'
resultPath=privateRoot||'/eyepoke-foreign-result-synthetic.json'
call charout jobPath,jobText
call charout jobPath

if invoker~preflightPaths(jobPath,resultPath)<>'ADMITTED' then raise syntax 93.900 array('Private preflight rejected valid job')
rc=invoker~run(methodId,jobPath,resultPath)
if rc<>0 then raise syntax 93.900 array('Foreign runtime returned nonzero',rc)
resultData=.json~fromJsonFile(resultPath)
if resultData['status']<>'NOT_APPLICABLE' then raise syntax 93.900 array('Unexpected synthetic status')
if resultData['methodology_id']<>methodId then raise syntax 93.900 array('Provider method mismatch')
if resultData['reason_code']<>'SYNTHETIC_ONLY_NO_MEDIA' then raise syntax 93.900 array('Wrong synthetic fixture')
if rxfuncquery('SysFileDelete')=0 then do
  call SysFileDelete resultPath
  call SysFileDelete jobPath
end
say 'PASS embedded Foreign Runtime video provider smoke 5/5 (synthetic, private root)'
exit 0

::requires 'json.cls'
::requires 'MediaReferenceVideoProviders.cls'
::requires 'MediaForeignVideoInvoker.cls'
