parse arg root
if root=='' then exit 2
qroot=root||'/queue'
jroot=root||'/admission'
manager=.ObjectQueueManager~new(qroot,.QueueGraphPayloadCodec~new,'admin')
call require manager~createQueue('DEPLOY','PERMANENT','WIRE',0,'admin'),'queue'
call require manager~grant('DEPLOY','sender',.QueueAccess~PUT,'admin'),'send'
call require manager~grant('DEPLOY','worker',.QueueAccess~GET,'admin'),'receive'
call require manager~grant('DEPLOY','worker',.QueueAccess~BROWSE,'admin'),'browse'
body=.table~new
body['contract']='wire.deployment.command/0.1'
body['requestId']='req-001'
body['artifactDigest']='sha256:'||copies('a',64)
body['artifactRef']='storage-fabric://app/notnotes'
body['target']='ed209h:staging'
opts=.table~new
opts['persistent']=.true
call require manager~put('DEPLOY',body,opts,'sender'),'PUT'
manager=.ObjectQueueManager~new(qroot,.QueueGraphPayloadCodec~new,'admin')
call check manager~depth('DEPLOY','worker')~value['ready']=1,'ready recovered'
journal=.WireDeploymentAdmissionJournal~new(jroot)
ingress=.WireDeploymentQueueIngress~new(manager,'DEPLOY','worker',.TestVerifier~new,journal)
call check ingress~pollOne='ACCEPTED','accepted'
call check manager~depth('DEPLOY','worker')~value['total']=0,'ACK persisted'
call require manager~put('DEPLOY',body,opts,'sender'),'retry'
manager=.ObjectQueueManager~new(qroot,.QueueGraphPayloadCodec~new,'admin')
journal=.WireDeploymentAdmissionJournal~new(jroot)
ingress=.WireDeploymentQueueIngress~new(manager,'DEPLOY','worker',.TestVerifier~new,journal)
call check ingress~pollOne='DUPLICATE_REQUEST','duplicate denied'
call check journal~pending~items=1,'single pending'
say 'PASS permanent queue and ledger recovery'
exit 0
check: procedure
 use strict arg okay,label
 if \okay then do
  say 'FAIL' label
  exit 1
 end
 say 'PASS' label
 return
require: procedure
 use strict arg r,label
 if \r~ok then do
  say 'FAIL' label r~code
  exit 1
 end
 return
::class TestVerifier
::method validateCommand
 return .true
::requires 'WireDeploymentAdmissionJournal.cls'
::requires 'WireDeploymentQueueIngress.cls'
::requires 'ObjectQueueFabric.cls'
