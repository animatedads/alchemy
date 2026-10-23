/* Executable registration, allowlisting, callback and compatibility contracts. */
checks=0
registry=.RpcServiceRegistry~new
svc=.Catalog~new
call check registry~registerMethod('catalog','get',svc,'fetch') == registry,'register explicit method'
call check registry~registerCallbackMethod('catalog','watch',svc,'watch') == registry,'register callback method'
call check registry~resolve('catalog','get')~methodName == 'fetch','mapped receiver method is explicit'
call check registry~resolve('catalog','secret') == .nil, 'private/unregistered methods not reachable'
call check registry~resolve('CATALOG','get') == .nil, 'service names case sensitive'
call check registry~resolve('catalog','GET') == .nil, 'method names case sensitive'
dispatcher=.RpcServiceDispatcher~new(registry)
params=.directory~new;params['item']='0007'
res=dispatcher~invoke('catalog','get',params,.nil)
call check res~ok & res~value == 'item:0007', 'inbound operation invokes mapped object method'
res=dispatcher~invoke('catalog','secret',params,.nil)
call check \res~ok & res~fault~code == 'NOT_FOUND', 'unregistered method fails closed'
res=dispatcher~invoke('other','get',params,.nil)
call check \res~ok & res~fault~code == 'NOT_FOUND', 'unknown service fails closed'
res=dispatcher~invoke('catalog','watch',params,.nil)
call check \res~ok & res~fault~code == 'INVALID_INVOCATION','unary cannot invoke callback operation'
sink=.Sink~new
res=dispatcher~invokeCallback('catalog','watch',params,.nil,sink)
call check res~ok & res~value == 'stream-launched', 'callback operation dispatches'
call check sink~items == 2 & sink~completed == 1,'callback sink gets values and completion'
call check sink~last == 'second:0007','callback events preserve values'
res=dispatcher~invokeCallback('catalog','get',params,.nil,sink)
call check \res~ok & res~fault~code == 'INVALID_INVOCATION','callback call cannot invoke unary registration'
res=dispatcher~invokeCallback('catalog','watch',params,.nil,.Object~new)
call check \res~ok & res~fault~code == 'INVALID_ARGUMENT','callback sink interface enforced'
sink~cancel
res=dispatcher~invokeCallback('catalog','watch',params,.nil,sink)
call check res~ok & sink~items == 2,'callback observes cancellation'
map=.directory~new
map['count']='countItems'
map['panic']='panic'
call check registry~registerObject('inventory',svc,map)==registry,'bulk explicit registration'
res=dispatcher~invoke('inventory','count',.nil,.nil)
call check res~ok & res~value == 5,'bulk registered method invoked'
res=dispatcher~invoke('inventory','panic',.nil,.nil)
call check \res~ok & res~fault~code == 'INTERNAL','implementation error masked'
badmap=.directory~new
badmap['safe']='fetch'
badmap['wrong']='nonexistent'
call check rejectsBadMap(registry,svc,badmap),'bulk bad method rejected'
call check registry~resolve('atomic','safe') == .nil,'bulk register atomic rollback'
call check rejectsDuplicate(registry,svc),'duplicate rejected'
call check registry~unregister('inventory','count'),'explicit revocation'
res=dispatcher~invoke('inventory','count',.nil,.nil)
call check \res~ok & res~fault~code == 'NOT_FOUND','revocation denies subsequent invokes'
old=.OldHandler~new
unused = registry~register('legacy','echo',old)
res=dispatcher~invoke('legacy','echo',params,.nil)
call check res~ok & res~value == 'legacy:0007','old invoke(operation,args,context) supported'
unused = registry~freeze
call check rejectsFrozen(registry,svc),'frozen registry rejects addition'
call check registry~frozen,'frozen registry is immutable'
say 'PASS' checks 'registry/dispatcher checks'
exit 0
check:
  use strict arg expr,label
  if \expr then do
    say 'FAIL' label
    exit 1
  end
  checks += 1
return
rejectsBadMap: procedure
  use strict arg registry,svc,badmap
  signal on syntax name caught
  ignored=registry~registerObject('atomic',svc,badmap)
  signal off syntax
  return .false
caught:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'Expected test exception' rc sigl condition("C") condition("D")
  return .true
rejectsDuplicate: procedure
  use strict arg registry,svc
  signal on syntax name caught
  ignored=registry~registerMethod('catalog','get',svc,'fetch')
  signal off syntax
  return .false
caught:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'Expected test exception' rc sigl condition("C") condition("D")
  return .true
rejectsFrozen: procedure
  use strict arg registry,svc
  signal on syntax name caught
  ignored=registry~registerMethod('catalog','new',svc,'fetch')
  signal off syntax
  return .false
caught:
  signal off syntax
  if value('OOREXX_RPC_DEBUG_DIAGNOSTICS',,'ENVIRONMENT') == '1' then
    say 'Expected test exception' rc sigl condition("C") condition("D")
  return .true
::class Catalog
::method fetch
  use strict arg arguments,context
  return 'item:' || arguments['item']
::method countItems
  use strict arg arguments,context
  return 5
::method secret
  return 'never expose by default'
::method panic
  raise syntax 93.900 additional('SECRET INTERNAL DETAILS')
::method watch
  use strict arg arguments,context,sink
  if sink~isCancelled then return 'stream-cancelled'
  sink~onNext('first:' || arguments['item'])
  sink~onNext('second:' || arguments['item'])
  sink~onComplete
  return 'stream-launched'
::class OldHandler
::method invoke
  use strict arg operation,arguments,context
  return 'legacy:' || arguments['item']
::class Sink
::attribute items get
::attribute completed get
::attribute last get
::attribute cancelled get
::method init
  expose items completed last cancelled
  items=0;completed=0;last='';cancelled=.false
::method onNext
  expose items last
  use strict arg value
  items+=1
  last=value
  return .true
::method onComplete
  expose completed
  use strict arg status=.nil
  completed+=1
  return .true
::method onFault
  use strict arg fault
  return .true
::method isCancelled
  expose cancelled
  return cancelled
::method cancel
  expose cancelled
  cancelled=.true
::requires 'RpcServiceCore.cls'
