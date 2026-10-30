parse arg root
if root=='' then exit 2
j=.WireDeploymentAdmissionJournal~new(root)
body=.table~new
body['requestId']='deployment-7'
body['artifactDigest']='sha256:'||copies('a',64)
body['artifactRef']='storage-fabric://wapp/releases/a'
body['target']='ed209h:staging'
call check j~recordDisposition('fabric-delivery-1','ACCEPTED',body)~ok,'admitted'
authority=.TestProbeAuthority~new
gate=.WireDeploymentLiveEvidenceGate~new(j,authority)
e=.HostedModuleEvidence~new('notnotes')
e~staged=.true
e~packageLoadable=.true
e~composed=.true
e~activated=.true
e~hostGeneration='sha-a'
e~probePath='/apps/notnotes'
e~probeStatus='PASS'
e~requestId='deployment-7'
r=.WireDeploymentLiveProbeReceipt~new('deployment-7','notnotes',body['artifactDigest'],body['target'],'sha-a','/apps/notnotes',e,'storage-fabric://evidence/probe-a')
call check gate~confirm(r)~code='LIFECYCLE_NOT_PROBED','cannot complete before live probe'
call check j~pending~items=1,'pending preserved'
e~probed=.true
authority~allow=.false
call check gate~confirm(r)~code='EXTERNAL_PROBE_UNVERIFIED','external authority denial'
authority~allow=.true
wrong=.WireDeploymentLiveProbeReceipt~new('deployment-7','notnotes',body['artifactDigest'],'other-target','sha-a','/apps/notnotes',e,'storage-fabric://evidence/probe-a')
call check gate~confirm(wrong)~code='ADMISSION_MISMATCH','target mismatch'
call check gate~confirm(.nil)~code='RECEIPT_REQUIRED','missing receipt'
call check gate~confirm('fake')~code='INVALID_RECEIPT_TYPE','wrong type'
unsigned=.WireDeploymentLiveProbeReceipt~new('deployment-7','notnotes',body['artifactDigest'],body['target'],'sha-a','/apps/notnotes',e,'http://unsigned/probe')
call check gate~confirm(unsigned)~code='IMMUTABLE_EVIDENCE_REQUIRED','unmanaged evidence'
badApp=.WireDeploymentLiveProbeReceipt~new('deployment-7','other',body['artifactDigest'],body['target'],'sha-a','/apps/notnotes',e,'storage-fabric://evidence/probe-a')
call check gate~confirm(badApp)~code='APPLICATION_MISMATCH','wrong app'
e~probeStatus='HTTP_CONNECTED_ONLY'
call check gate~confirm(r)~code='PROBE_PATH_OR_STATUS_INVALID','HTTP alone not semantic ready'
e~probeStatus='PASS'
e~hostGeneration='older'
call check gate~confirm(r)~code='GENERATION_OR_REQUEST_MISMATCH','generation fenced'
e~hostGeneration='sha-a'
call check gate~confirm(r)~ok,'verified terminal'
call check j~pending~items=0,'pending cleared'
call check gate~confirm(r)~code='ALREADY_COMPLETED','idempotent'
other=.WireDeploymentLiveProbeReceipt~new('deployment-7','notnotes',body['artifactDigest'],body['target'],'sha-a','/apps/notnotes',e,'storage-fabric://evidence/other')
call check gate~confirm(other)~code='COMPLETION_CONFLICT','conflicting evidence'
reloaded=.WireDeploymentAdmissionJournal~new(root)
call check reloaded~completion('deployment-7')[1]='PROBED_ACTIVE','durable replay'
say 'PASS live evidence gate'
exit 0
check: procedure
 use strict arg okay,label
 if \okay then do
  say 'FAIL' label
  exit 1
 end
 say 'PASS' label
 return
::class TestProbeAuthority
::attribute allow
::method init
 self~allow=.true
::method verifyLiveProbe
 expose allow
 use strict arg receipt,admission
 return allow
::requires 'WireDeploymentLiveEvidenceGate.cls'
