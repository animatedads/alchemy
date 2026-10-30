/* Authenticated route enforcement must be independent of user payload. */
base = .ConnectRoutePolicy~new
attestor = .TestRouteAttestor~new
secure = .ConnectAuthenticatedRoutePolicy~new(base,attestor)
selector = .ConnectSelector~new(secure)
remote = .TestSecureCall~new
selector~register('RPC', .ConnectCallAdapter~new(remote,'RPC','MI.MN1'),'MI.MN1')
base~allow('telemetry.internode','REQUEST','RPC','MI.MN1')
secure~requireAuthenticated('MI.MN1','RPC')
intent = .ConnectIntent~new('telemetry.internode','REQUEST','IMMEDIATE','RPC','MI.MN1')
call check selector~select(intent)~code == 'POLICY_DENIED','remote denied without verified transport identity'
call check remote~calls == 0,'unverified remote not invoked'
attestor~verified = .true
call check selector~execute(intent)~ok,'verified route admitted'
call check remote~calls == 1,'only verified connection executed'
attestor~verified = .false
spoof = .Directory~new
spoof['ldapAuthenticated'] = .true
spoof['httpsVerified'] = .true
spoof['peer'] = 'MI.MN1'
forged = .ConnectIntent~new('telemetry.internode','REQUEST','IMMEDIATE','RPC','MI.MN1',spoof)
call check selector~select(forged)~code == 'POLICY_DENIED','caller-supplied identity evidence is not trusted'
attestor~verified = .true
base~deny('telemetry.internode','REQUEST','RPC','MI.MN1')
call check selector~select(intent)~code == 'POLICY_DENIED','route denial overrides trusted attestation'
base2 = .ConnectRoutePolicy~new
base2~allow('telemetry.internode','REQUEST','RPC','MI.MN1')
attestor~verified = .true
secure2 = .ConnectAuthenticatedRoutePolicy~new(base2,attestor)
secure2~requireAuthenticated('MI.MN1','RPC')
selector~setPolicy(secure2)
attestor~throwFault = .true
call check selector~select(intent)~code == 'POLICY_DENIED','attestor exception fails closed'
attestor~throwFault = .false
attestor~verified = .true
call check selector~execute(intent)~ok,'verified attestor recovers after fault'
call check remote~calls == 2,'no extra invocation during rejection'
call check secure2~permitted(.ConnectIntent~new('other.service','REQUEST','IMMEDIATE','RPC','MI.MN1'),'RPC') == .false,'unregistered operation denied'
plain = .ConnectAuthenticatedRoutePolicy~new(base2,attestor)
attestor~verified = .false
call check plain~permitted(intent,'RPC') == .false,'remote unmarked destination also requires authority'
attestor~verified = .true
call check plain~permitted(intent,'RPC'),'remote route can be admitted only by trusted attestor'
base2~allow('bulk.backup','ENQUEUE','QUEUE','MI.MN1')
base2~allow('grid.job','REQUEST','RTO2','MI.MN1')
attestor~verified = .false
call check plain~permitted(.ConnectIntent~new('bulk.backup','ENQUEUE','DURABLE','QUEUE','MI.MN1'),'QUEUE') == .false,'queue provider defaults to attestation required'
call check plain~permitted(.ConnectIntent~new('grid.job','REQUEST','CONTINUITY','RTO2','MI.MN1'),'RTO2') == .false,'RTO2 defaults to attestation required'
say 'PASS authenticated route policy: ACL, verified authority, spoof rejection, fail-closed fault'
exit 0
check: procedure
  use strict arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return
::class TestRouteAttestor
::attribute verified
::attribute throwFault
::method init
  expose verified throwFault
  verified = .false
  throwFault = .false
::method authorizeRoute
  expose verified throwFault
  use strict arg intent, provider
  if throwFault then raise syntax 93.900 additional('test secret: should never be logged')
  return verified
::class TestSecureCall
::attribute calls
::method init
  expose calls
  calls=0
::method request
  expose calls
  use strict arg operation,payload
  calls += 1
  return .TestSecureReply~new
::method notify
  return .true
::class TestSecureReply
::method ok
  return .true
::method result
  return 'accepted'
::method fault
  return .nil
::requires 'ConnectSelector.cls'
::requires 'ConnectAuthenticatedRoutePolicy.cls'
