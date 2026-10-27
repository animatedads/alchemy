/* Queue Fabric durable ingress: disposition committed before ACK. */
::class WireDeploymentQueueIngress public
::method init
  expose manager queueName principal verifier journal
  use strict arg manager,queueName,principal,verifier,journal
  if manager==.nil | verifier==.nil | journal==.nil | queueName=='' | principal=='' then raise syntax 93.900 array('Wire deployment ingress requires bound authority')

::method pollOne
  expose manager queueName principal verifier journal
  claim=manager~claim(queueName,principal)
  if \claim~ok then return 'NO_DELIVERY:'||claim~code
  p=claim~value
  body=p~payload
  outcome='ACCEPTED'
  if \self~shapeValid(body) then outcome='REJECTED_SHAPE'
  else do
    if \verifier~validateCommand(body) then outcome='REJECTED_AUTHORITY'
  end
  receipt=journal~recordDisposition(p~packageId,outcome,body)
  if \receipt~ok then do
    ignored=manager~release(queueName,p~packageId,p~claimToken,principal,'deployment disposition not durable')
    if \ignored~ok then return 'RELEASE_FAILED:'||ignored~code
    return 'RETRY_REQUIRED'
  end
  ack=manager~ack(queueName,p~packageId,p~claimToken,principal)
  if \ack~ok then return 'ACK_FAILED:'||ack~code
  return receipt~value

/* Exact v0.1 envelope. A changed semantic field requires a new version. */
::method shapeValid private
  use strict arg body
  if body==.nil | \body~hasMethod('HASINDEX') | \body~hasMethod('ITEMS') then return .false
  if body~items<>5 then return .false
  do required over .array~of('contract','artifactDigest','artifactRef','target','requestId')
    if \body~hasIndex(required) then return .false
  end
  if body['contract']<>'wire.deployment.command/0.1' then return .false
  digest=body['artifactDigest']~string
  if digest~length<>71 | digest~left(7)<>'sha256:' then return .false
  if digest~substr(8)~verify('0123456789abcdef')<>0 then return .false
  ref=body['artifactRef']~string
  if ref~left(17)<>'storage-fabric://' | ref~length<=17 then return .false
  requestId=body['requestId']~string
  if requestId=='' | requestId~length>128 then return .false
  if requestId~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-')<>0 then return .false
  target=body['target']~string
  if target=='' | target~length>192 then return .false
  if target~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-')<>0 then return .false
  return .true
