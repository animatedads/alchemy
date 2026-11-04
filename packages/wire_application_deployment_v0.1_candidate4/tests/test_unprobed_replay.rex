parse arg root
if root=='' then exit 2
j=.WireDeploymentAdmissionJournal~new(root)
body=.table~new
body['requestId']='deployment-incomplete'
body['artifactDigest']='sha256:'||copies('b',64)
body['artifactRef']='storage-fabric://wapp/releases/b'
body['target']='ed209h:staging'
call check j~recordDisposition('fabric-delivery-2','ACCEPTED',body)~ok,'admit pending'
g=.WireDeploymentLiveEvidenceGate~new(j,.RefuseProbeAuthority~new)
e=.HostedModuleEvidence~new('notnotes')
e~staged=.true
r=.WireDeploymentLiveProbeReceipt~new('deployment-incomplete','notnotes',body['artifactDigest'],body['target'],'sha-b','/apps/notnotes',e,'storage-fabric://evidence/pending')
call check g~confirm(r)~code='GENERATION_OR_REQUEST_MISMATCH','no generation'
j=.WireDeploymentAdmissionJournal~new(root)
call check j~pending~items=1,'replay remains pending'
call check j~completion('deployment-incomplete')==.nil,'no false completion'
say 'PASS unprobed replay'
exit 0
check: procedure
 use strict arg okay,label
 if \okay then do
  say 'FAIL' label
  exit 1
 end
 say 'PASS' label
 return
::class RefuseProbeAuthority
::method verifyLiveProbe
 return .false
::requires 'WireDeploymentLiveEvidenceGate.cls'
