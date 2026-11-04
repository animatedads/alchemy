/* Real, in-process Foreign Python bridge smoke test; no media bytes.
 * Requires ooRexx r13196, Foreign Runtime v0.22.6 installed, Python 3.
 * Run from the Media Methodologies package root with src on REXX_PATH.
 * The synthetic provider has NO OpenCV/NumPy dependency.
 */
registry=.MediaReferenceVideoProviderRegistry~new('tests/fixtures/foreign_runtime_video')
methodId='VIDEO.RECON.FLOW_WARP_ACCUMULATE'
if \registry~supports(methodId) then raise syntax 93.900 array('Unknown synthetic method')
invoker=.MediaForeignVideoInvoker~new('tests/fixtures/foreign_runtime_video')
jobPath='tests/fixtures/foreign_runtime_video/job.json'
resultPath='/tmp/alchemy_foreign_video_smoke_synthetic.json'
rc=invoker~run(methodId,jobPath,resultPath)
if rc<>0 then raise syntax 93.900 array('Foreign runtime returned nonzero',rc)
resultData=.json~fromJsonFile(resultPath)
if resultData['status']<>'NOT_APPLICABLE' then raise syntax 93.900 array('Unexpected synthetic result status')
if resultData['methodology_id']<>methodId then raise syntax 93.900 array('Provider method mismatch')
if resultData['reason_code']<>'SYNTHETIC_ONLY_NO_MEDIA' then raise syntax 93.900 array('Wrong synthetic fixture')
if rxfuncquery('SysFileDelete')=0 then call SysFileDelete resultPath
say 'PASS embedded Foreign Runtime video provider smoke test 4/4 (synthetic)'
exit 0

::requires 'json.cls'
::requires 'MediaReferenceVideoProviders.cls'
::requires 'MediaForeignVideoInvoker.cls'
