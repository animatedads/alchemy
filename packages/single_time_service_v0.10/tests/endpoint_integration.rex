/* Integration against real ConnectSelector dev2 and RPC Service Core dev1.
 * No JSON-RPC/QueueFabric availability or persistence is presumed. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
s~registerZone(p~load('Australia/Sydney'))
e=.TimeServiceEndpoint~new(s)
args=.directory~new
args['zone']='Europe/London'
args['local']='2026-10-25T01:30:00'

policy=.ConnectRoutePolicy~new
policy~allow('time.zone.resolve','REQUEST','DIRECT','LOCAL')
policy~allow('time.recurrence.expand','REQUEST','DIRECT','LOCAL')
selector=.ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectCallAdapter~new(e,'DIRECT','LOCAL'),'LOCAL')
request=.ConnectIntent~new('time.zone.resolve','REQUEST','IMMEDIATE','AUTO','LOCAL')
reply=selector~execute(request,args)
if \reply~ok | \reply~completed | reply~durable then do; say 'FAIL direct request guarantee'; exit 1; end
if reply~value['status'] \= 'FOLD' then do; say 'FAIL direct resolution'; exit 1; end
if reply~value['candidates']~items \= 2 then do; say 'FAIL fold candidates'; exit 1; end

/* The same semantic method, published via RPC Service Core's exact method
 * registry: wire bindings may use it without giving raw object reflection. */
registry=.RpcServiceRegistry~new
e~publishTo(registry)
registry~freeze
d=.RpcServiceDispatcher~new(registry)
r=d~invoke('time','zone.resolve',args)
if \r~ok | r~value['status'] \= 'FOLD' then do; say 'FAIL RPC registry dispatch'; exit 1; end
r=d~invoke('time','unpublished',args)
if r~ok | r~fault~code \= 'NOT_FOUND' then do; say 'FAIL unknown RPC method'; exit 1; end

arguments=.directory~new
arguments['id']='school-time'
arguments['zone']='Europe/London'
arguments['anchorLocal']='2026-10-26T09:00:00'
arguments['fromLocal']='2026-10-26T00:00:00'
arguments['throughLocal']='2026-10-30T23:59:59'
arguments['frequency']='WEEKLY'
arguments['weekdays']='MO,TU,WE,TH,FR'
req=.ConnectIntent~new('time.recurrence.expand','REQUEST','IMMEDIATE','AUTO','LOCAL')
r=selector~execute(req,arguments)
if \r~ok | r~value['generatedCount'] \= 5 then do; say 'FAIL direct recurrence' r~ok; exit 1; end
if r~value['occurrences'][1]['local'] \= '2026-10-26T09:00:00' then do; say 'FAIL date sequence'; exit 1; end

/* No implicit fallback to ENQUEUE, notify, unregistered RPC or unauthorised. */
r=selector~execute(.ConnectIntent~new('time.zone.resolve','REQUEST','IMMEDIATE','RPC','LOCAL'),args)
if r~ok | r~code \= 'UNREGISTERED' then do; say 'FAIL unregistered RPC'; exit 1; end
r=selector~execute(.ConnectIntent~new('time.zone.resolve','ENQUEUE','DURABLE','AUTO','LOCAL'),args)
if r~ok | r~code \= 'NO_ELIGIBLE_PROVIDER' then do; say 'FAIL queue not optional'; exit 1; end
r=selector~execute(.ConnectIntent~new('time.zone.resolve','NOTIFY','BEST_EFFORT','DIRECT','LOCAL'),args)
if r~ok | r~code \= 'POLICY_DENIED' then do; say 'FAIL notification policy'; exit 1; end
bad=.directory~new
bad['zone']='Europe/London'
r=selector~execute(request,bad)
if r~ok | r~code \= 'CALL_FAILED' then do; say 'FAIL invalid client arguments'; exit 1; end

say 'PASS: ConnectSelector direct, strict grants, independent Queue and explicit RPC service registration'
::requires 'TimeServiceEndpoint.cls'
::requires 'TzifZoneProvider.cls'
::requires 'ConnectSelector.cls'
::requires 'RpcServiceCore.cls'
