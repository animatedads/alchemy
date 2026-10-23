/* Queue Fabric ingress: durable disposition before ACK; RELEASE on journal failure. */
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
  recorded=journal~recordDisposition(p~packageId,outcome,body)
  if \recorded then do
    ignored=manager~release(queueName,p~packageId,p~claimToken,principal,'deployment disposition not durable')
    if \ignored~ok then return 'RELEASE_FAILED:'||ignored~code
    return 'RETRY_REQUIRED'
  end
  ack=manager~ack(queueName,p~packageId,p~claimToken,principal)
  if \ack~ok then return 'ACK_FAILED:'||ack~code
  return outcome
::method shapeValid private
  use strict arg body
  if body==.nil | \body~hasMethod('HASINDEX') then return .false
  if \body~hasIndex('contract') | \body~hasIndex('artifactDigest') | \body~hasIndex('artifactRef') | \body~hasIndex('target') | \body~hasIndex('requestId') then return .false
  if body['contract']<>'wire.deployment.command/0.1' then return .false
  if body['artifactDigest']=='' | body['artifactRef']=='' | body['target']=='' | body['requestId']=='' then return .false
  return .true
