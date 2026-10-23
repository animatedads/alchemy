https=.TestHttpsRoutes~new
wire=.WireUIServer~new(.nil,.Object~new,'admin')
gateway=.WireDeploymentGatewaySlots~new
verifier=.TestVerifier~new
probe=.TestReadiness~new
coordinator=.WireHostedDeploymentCoordinator~new(https,wire,gateway,verifier,probe)
appA=.StubHostedApp~new('one','access-one')
appA2=.StubHostedApp~new('one','access-one')
appB=.StubHostedApp~new('two','access-two')
bindingA=.TestBinding~new('a')
bindingB=.TestBinding~new('b')
handler=.TestHandler~new
r=coordinator~activate('approved',appA,'sha1','/apps/one',handler,'respond',bindingA)
call check r~ok & r~code='PUBLISHED_AWAITING_LIVE_PROBE','application one published unprobed'
r=coordinator~activate('approved',appB,'sha1','/apps/two',handler,'respond',bindingB)
call check r~ok & r~code='PUBLISHED_AWAITING_LIVE_PROBE','application two published unprobed'
call check https~hostedRouteGeneration('GET','/apps/two')='sha1','separate path'
r=coordinator~activate('bad',appA2,'sha2','/apps/one',handler,'respond',bindingA,'sha1')
call check r~code='UNVERIFIED_ARTIFACT','unverified denied'
probe~allowed=.false
r=coordinator~activate('approved',appA2,'sha2','/apps/one',handler,'respond',bindingA,'sha1')
call check r~code='READINESS_FAILED','readiness fail closed'
probe~allowed=.true
https~denyNext=.true
r=coordinator~activate('approved',appA2,'sha2','/apps/one',handler,'respond',bindingA,'sha1')
call check r~code='HTTP_COMMIT_FAILED','failed publication detected'
call check wire~hostedApplication('one')==appA,'rollback semantic app'
call check gateway~generation('one')='sha1','rollback gateway'
call check https~hostedRouteGeneration('GET','/apps/one')='sha1','previous route still live'
call check wire~hostedGeneration('two')='sha1','other app unaffected'
r=coordinator~activate('approved',appA2,'sha2','/apps/one',handler,'respond',bindingA,'sha1')
call check r~ok & r~code='PUBLISHED_AWAITING_LIVE_PROBE','upgrade published unprobed'
call check wire~retiredHostedApplication('one','sha1')==appA,'old object retained'
say 'PASS wire hosted coordinator'
exit 0
check: procedure
  use strict arg result,name
  if \result then do
    say 'FAIL' name
    exit 1
  end
  say 'PASS' name
  return
::class TestVerifier
::method verifyReceipt
  use strict arg receipt,appId,generation,mount
  return receipt='approved'
::class TestReadiness
::attribute allowed
::method init
  self~allowed=.true
::method ready
  expose allowed
  return allowed
::class StubHostedApp
::attribute applicationId get
::attribute accessPointId get
::method init
  expose applicationId accessPointId
  use strict arg applicationId,accessPointId
::class TestBinding
::method init
  use strict arg name
::method provision
  return .true
::method browserBootstrap
  return .directory~new
::class TestHandler
::method respond
  return 'OK'
::class TestHttpsRoutes
::attribute denyNext
::method init
  expose table denyNext
  table=.HttpsHostedRoutes~new
  denyNext=.false
::method hostedRouteGeneration
  expose table
  use strict arg method,path
  return table~generation(method,path)
::method publishHostedRoute
  expose table denyNext
  use strict arg method,path,appId,generation,handler,selector,expected
  if denyNext then do
    denyNext=.false
    return .false
  end
  return table~publish(method,path,appId,generation,handler,selector,expected)
::requires 'WireHostedDeploymentCoordinator.cls'
::requires 'WireUIServer.cls'
::requires 'WireDeploymentGatewaySlots.cls'
::requires 'HttpsHostedRoutes.cls'
