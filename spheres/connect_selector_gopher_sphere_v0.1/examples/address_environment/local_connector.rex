/* RFE #882 integration test: actual ConnectSelector DirectCall.
 * Do not run on r13196: the handler API needs r13289+.
 * Set REXX_PATH to the exact ConnectSelector dev8 src directory.
 */
policy = .ConnectRoutePolicy~new
policy~allow('status.read','REQUEST','DIRECT','LOCAL')
selector = .ConnectSelector~new(policy)
fixture = .LocalStatusFixture~new
selector~register('DIRECT', .ConnectCallAdapter~new(fixture,'DIRECT','LOCAL'), 'LOCAL')
.CommandHandler~register('ALCHEMY_LOCAL', .AlchemyConnectAddressLocal~new(selector))

address ALCHEMY_LOCAL "CALL LOCAL status.read"
if rc \== 0 then do
  say 'FAIL approved local DirectCall, RC' rc
  exit 1
end
if fixture~calls \== 1 then do
  say 'FAIL invocation count after approved command'
  exit 2
end

address ALCHEMY_LOCAL "CALL LOCAL status.delete"
if rc \== 13 then do
  say 'FAIL unregistered operation, RC' rc
  exit 3
end
if fixture~calls \== 1 then do
  say 'FAIL denied command was dispatched'
  exit 4
end

/* A misconfigured DIRECT adapter at a nonlocal destination must still fail. */
remoteFixture = .LocalStatusFixture~new
policy~allow('status.read','REQUEST','DIRECT','REMOTE')
selector~register('DIRECT', .ConnectCallAdapter~new(remoteFixture,'DIRECT','REMOTE'), 'REMOTE')
address ALCHEMY_LOCAL "CALL REMOTE status.read"
if rc \== 13 then do
  say 'FAIL unexpected destination, RC' rc
  exit 5
end
if fixture~calls \== 1 | remoteFixture~calls \== 0 then do
  say 'FAIL remote destination dispatched via local adapter'
  exit 6
end

address ALCHEMY_LOCAL "CALL LOCAL status.read && rm"
if rc \== 64 then do
  say 'FAIL extra tokens not rejected, RC' rc
  exit 7
end
address ALCHEMY_LOCAL "SHELL LOCAL status.read"
if rc \== 64 then do
  say 'FAIL shell-like command not rejected, RC' rc
  exit 8
end
if fixture~calls \== 1 then do
  say 'FAIL invalid command caused side effect'
  exit 9
end

/* An accepted receipt without execution completion may not return RC zero. */
.CommandHandler~register('ALCHEMY_ASYNC_LOCAL', .AlchemyConnectAddressLocal~new(.IncompleteSelector~new))
address ALCHEMY_ASYNC_LOCAL "CALL LOCAL status.read"
if rc \== 75 then do
  say 'FAIL accepted but incomplete call returned RC' rc
  exit 10
end

say 'PASS RFE882 local ADDRESS -> ConnectSelector: completed, denied, no shell, incomplete'
exit 0

::class IncompleteSelector
::method policy
  return .ConnectRoutePolicy~new
::method execute
  use strict arg intention, payload
  return .ConnectResult~success('DIRECT',.nil,.true,.false,.false)

::class LocalStatusFixture
::attribute calls
::method init
  expose calls
  calls = 0
::method request
  expose calls
  use strict arg operation, payload
  calls += 1
  return .LocalStatusReply~new
::method notify
  return .false

::class LocalStatusReply
::method ok
  return .true
::method result
  return 'local-ok'
::method fault
  return .nil

::requires 'ConnectSelector.cls'
::requires 'AlchemyConnectAddressLocal.cls'
