/* Read-only transport qualification with exact v0.4 connector dependencies. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
path='tests/.time_impact_v07_rpc.journal'
unused=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
r=l~addCalendar('SCHOOL','Europe/London','term',0)
r=l~addEvent('007','SCHOOL','Dinner','MEAL','2026-10-01','2026-12-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','e1',r)
r=l~bindPhrase('SCHOOL','dinner','007',r)
r=l~moveDate('007','2026-10-26','13:00:00','Changed',r)
endpoint=.TimeServiceEndpoint~new(s,l)
a=.directory~new
a['institution']='SCHOOL'; a['phrase']='dinner'
a['fromDate']='2026-10-26'; a['throughDate']='2026-10-26'
a['fromRevision']=3; a['toRevision']=4
policy=.ConnectRoutePolicy~new
policy~allow('time.impact.analyze','REQUEST','DIRECT','LOCAL')
selector=.ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectCallAdapter~new(endpoint,'DIRECT','LOCAL'),'LOCAL')
response=selector~execute(.ConnectIntent~new('time.impact.analyze','REQUEST','IMMEDIATE','AUTO','LOCAL'),a)
if \response~ok | response~value['changedDays'] \= 1 then do; say 'FAIL DIRECT impact'; exit 1; end
rDenied=selector~execute(.ConnectIntent~new('time.impact.analyze','ENQUEUE','DURABLE','AUTO','LOCAL'),a)
if rDenied~ok then do; say 'FAIL impact falsely enqueued'; exit 1; end
reg=.RpcServiceRegistry~new
endpoint~publishTo(reg)
reg~freeze
result=.RpcServiceDispatcher~new(reg)~invoke('time','impact.analyze',a)
if \result~ok | result~value['changedDays'] \= 1 then do; say 'FAIL RPC Core impact'; exit 1; end
handler=.TimeJsonRpcHandler~new(endpoint)
methods=.JsonRpcMethodRegistry~new
methods~register('time.impact.analyze',handler)
client=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(methods)))
remotePolicy=.ConnectRoutePolicy~new
remotePolicy~allow('time.impact.analyze','REQUEST','RPC','LOOPBACK')
remote=.ConnectSelector~new(remotePolicy)
remote~register('RPC',.ConnectCallAdapter~new(client,'RPC','LOOPBACK'),'LOOPBACK')
wire=.directory~new
wire['institution']=.JsonString~new('SCHOOL'); wire['phrase']=.JsonString~new('dinner')
wire['fromDate']=.JsonString~new('2026-10-26'); wire['throughDate']=.JsonString~new('2026-10-26')
wire['fromRevision']=3; wire['toRevision']=4
response=remote~execute(.ConnectIntent~new('time.impact.analyze','REQUEST','IMMEDIATE','AUTO','LOOPBACK'),wire)
if \response~ok then do; say 'FAIL JSON-RPC impact' response~code response~detail; exit 1; end
v=response~value
if v['changedDays']~isA(.JsonString) | v['changedDays'] \= 1 then do; say 'FAIL numeric count'; exit 1; end
if \v['changes'][1]['before']['eventId']~isA(.JsonString) | v['changes'][1]['before']['eventId'] \= '007' then do; say 'FAIL preserved event identifier'; exit 1; end
if v['changes'][1]['utcDeltaSeconds']~isA(.JsonString) | v['changes'][1]['utcDeltaSeconds'] \= 2700 then do; say 'FAIL typed UTC delta'; exit 1; end
if \v['fromHeadChecksum']~isA(.JsonString) then do; say 'FAIL provenance typed string'; exit 1; end
if v['effect'] \= 'ADVISORY_ONLY' then do; say 'FAIL evidence advisory status'; exit 1; end
unused=SysFileDelete(path)
say 'PASS: advisory impact DIRECT, RPC Core, JSON-RPC loopback; no invented enqueue'
::requires 'TzifZoneProvider.cls'
::requires 'TimeServiceEndpoint.cls'
::requires 'TimeJsonRpcBinding.cls'
::requires 'ConnectSelector.cls'
::requires 'RpcServiceCore.cls'
