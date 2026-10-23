/* Verified admission, readiness and ordered publication of the same generation. */
::class WireHostedDeploymentResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use strict arg ok,code,detail=''
::class WireHostedDeploymentCoordinator public
::method init
  expose https wire gateway verifier readiness
  use strict arg https,wire,gateway,verifier,readiness
  if https==.nil | wire==.nil | gateway==.nil | verifier==.nil | readiness==.nil then raise syntax 93.900 array('Deployment authority dependencies required')
::method activate
  expose https wire gateway verifier readiness
  use strict arg receipt,app,generation,mount,handler,selector,binding,expected=''
  if app==.nil | binding==.nil | handler==.nil then return .WireHostedDeploymentResult~new(.false,'INVALID_ARGUMENT')
  appId=app~applicationId
  if generation=='' | appId=='' | mount=='' | mount~left(1)<>'/' then return .WireHostedDeploymentResult~new(.false,'INVALID_MANIFEST')
  if \verifier~verifyReceipt(receipt,appId,generation,mount) then return .WireHostedDeploymentResult~new(.false,'UNVERIFIED_ARTIFACT')
  if \readiness~ready(app,binding,handler,mount) then return .WireHostedDeploymentResult~new(.false,'READINESS_FAILED')
  current=wire~hostedGeneration(appId)
  if current<>expected | https~hostedRouteGeneration('GET',mount)<>expected | gateway~generation(appId)<>expected then return .WireHostedDeploymentResult~new(.false,'GENERATION_CONFLICT')
  oldApp=wire~hostedApplication(appId)
  oldBinding=gateway~binding(appId)
  if \gateway~publish(appId,generation,binding,expected) then return .WireHostedDeploymentResult~new(.false,'GATEWAY_COMMIT_FAILED')
  r=wire~publishHostedApplication(app,generation,expected)
  if \r~ok then do
    undone=self~undoGateway(appId,generation,expected,oldBinding)
    if \undone then return .WireHostedDeploymentResult~new(.false,'ROLLBACK_INCOMPLETE','gateway')
    return .WireHostedDeploymentResult~new(.false,'WIRE_COMMIT_FAILED',r~code)
  end
  if \https~publishHostedRoute('GET',mount,appId,generation,handler,selector,expected) then do
    wireRestored=self~undoWire(appId,generation,expected,oldApp)
    gatewayRestored=self~undoGateway(appId,generation,expected,oldBinding)
    if \wireRestored | \gatewayRestored then return .WireHostedDeploymentResult~new(.false,'ROLLBACK_INCOMPLETE','after HTTP failure')
    return .WireHostedDeploymentResult~new(.false,'HTTP_COMMIT_FAILED')
  end
  return .WireHostedDeploymentResult~new(.true,'PUBLISHED_AWAITING_LIVE_PROBE',generation)
::method undoGateway private
  expose gateway
  use strict arg appId,generation,expected,oldBinding
  if expected=='' then return gateway~retire(appId,generation)
  return gateway~publish(appId,expected,oldBinding,generation)
::method undoWire private
  expose wire
  use strict arg appId,generation,expected,oldApp
  if expected=='' then return wire~retireHostedApplication(appId,generation)~ok
  return wire~publishHostedApplication(oldApp,expected,generation)~ok
