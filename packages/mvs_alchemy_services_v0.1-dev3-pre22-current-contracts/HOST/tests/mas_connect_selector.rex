call testIdentity
call testSelector
call testServiceInjectionSurface
say 'PASS MAS_CONNECT_SELECTOR_PRE22'
exit 0

testIdentity:
  resolver=.MasFixedHostIdentityResolver~new('HERC01','QUALIFICATION_FIXED','smoke')
  identity=resolver~resolve('17')
  if identity~principalId <> 'HERC01' then raise syntax 88.900 array('IDENTITY_MISMATCH')
  return

testSelector:
  policy=.ConnectRoutePolicy~new
  policy~allow('mas.test.echo','REQUEST','DIRECT','LOCAL')
  selector=.ConnectSelector~new(policy)
  selector~register('DIRECT',.ConnectCallAdapter~new(.MasFakeCall~new,'DIRECT','LOCAL'),'LOCAL')
  port=.MasConnectSelectorPort~new(selector)
  answer=port~request('mas.test.echo','payload','DIRECT','LOCAL')
  if answer <> 'OK:mas.test.echo' then raise syntax 88.900 array('SELECTOR_RESULT_MISMATCH')
  explanation=port~explain('mas.test.echo','REQUEST','IMMEDIATE','DIRECT','LOCAL')
  if \explanation['ok'] then raise syntax 88.900 array('SELECTOR_EXPLAIN_FAILED')
  if explanation['provider'] <> 'DIRECT' then raise syntax 88.900 array('SELECTOR_PROVIDER_MISMATCH')
  return

testServiceInjectionSurface:
  /* Runtime compile/constructor test: external provider set can now be injected. */
  services=.MasVirtualServices~new
  gateway=.MasLiveGateway~new(37075,'/tmp/mas-pre22-constructor','',.nil,.nil,services)
  if gateway~services \== services then raise syntax 88.900 array('SERVICES_NOT_INJECTED')
  return

::class MasFakeReply public
::method init
  expose ok result fault
  use strict arg okArg,resultArg=.nil,faultArg=.nil
  ok=okArg; result=resultArg; fault=faultArg
::attribute ok get
::attribute result get
::attribute fault get

::class MasFakeCall public
::method request
  use strict arg operation,payload=.nil
  return .MasFakeReply~new(.true,'OK:'||operation)
::method notify
  use strict arg operation,payload=.nil
  return .true

::requires 'MasLiveGateway.cls'
::requires 'MasConnectSelectorBinding.cls'
