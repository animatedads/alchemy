manager=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
call require manager~createQueue('DEPLOY','TEMPORARY','WIRE',0,'admin'),'queue created'
call require manager~grant('DEPLOY','submitter',.QueueAccess~PUT,'admin'),'submit grant'
call require manager~grant('DEPLOY','deployer',.QueueAccess~GET,'admin'),'claim grant'
call require manager~grant('DEPLOY','deployer',.QueueAccess~BROWSE,'admin'),'browse grant'
verifier=.TestCommandVerifier~new
journal=.TestCommandJournal~new
ingress=.WireDeploymentQueueIngress~new(manager,'DEPLOY','deployer',verifier,journal)
body=.table~new
body['contract']='wire.deployment.command/0.1'
body['artifactDigest']='sha256:abc'
body['artifactRef']='storage://a'
body['target']='wire-demo'
body['requestId']='req1'
call require manager~put('DEPLOY',body,.table~new,'submitter'),'first submit'
call check ingress~pollOne='ACCEPTED','verified command recorded and ACKed'
call check manager~depth('DEPLOY','deployer')~value['total']=0,'queue empty after ACK'
body2=.table~new
body2['contract']='bad'
call require manager~put('DEPLOY',body2,.table~new,'submitter'),'malformed submit'
call check ingress~pollOne='REJECTED_SHAPE','malformed recorded and ACKed'
call check journal~recorded=2,'two disposition receipts'
body3=.table~new
body3['contract']='wire.deployment.command/0.1'
body3['artifactDigest']='sha256:xyz'
body3['artifactRef']='storage://b'
body3['target']='wire-demo'
body3['requestId']='req3'
call require manager~put('DEPLOY',body3,.table~new,'submitter'),'retry submit'
journal~canRecord=.false
call check ingress~pollOne='RETRY_REQUIRED','journal failure RELEASEs claim'
call check manager~depth('DEPLOY','deployer')~value['ready']=1,'released delivery visible again'
journal~canRecord=.true
call check ingress~pollOne='ACCEPTED','released delivery retried'
say 'PASS native Queue Fabric ingress'
exit 0
check: procedure
  use strict arg condition,label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  say 'PASS' label
  return
require: procedure
  use strict arg result,label
  if \result~ok then do
    say 'FAIL' label result~code
    exit 1
  end
  return
::class TestCommandVerifier
::method validateCommand
  use strict arg body
  return .true
::class TestCommandJournal
::attribute canRecord
::attribute recorded get
::method init
  expose canRecord recorded
  canRecord=.true
  recorded=0
::method recordDisposition
  expose canRecord recorded
  if \canRecord then return .false
  recorded=recorded+1
  return .true
::requires 'WireDeploymentQueueIngress.cls'
::requires 'ObjectQueueFabric.cls'
