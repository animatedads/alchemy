/* Existing RPC/ConnectSelector contract, no new transport or RPC dispatcher. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
path='tests/.time_authority_v06_rpc.journal'
unused=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
seq=l~addCalendar('SCHOOL','Europe/London','term-v1',0)
seq=l~addEvent('007','SCHOOL','Dinner','MEAL','2026-10-01','2026-12-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-v1',seq)
seq=l~bindPhrase('SCHOOL','dinner','007',seq)
seq=l~moveDate('007','2026-10-26','13:00:00','Change',seq)
endpoint=.TimeServiceEndpoint~new(s,l)
a=.directory~new
a['institution']='SCHOOL'; a['phrase']='dinner'; a['onDate']='2026-10-26'; a['asOfRevision']=3
policy=.ConnectRoutePolicy~new
policy~allow('time.event.resolve','REQUEST','DIRECT','LOCAL')
policy~allow('time.authority.info','REQUEST','DIRECT','LOCAL')
selector=.ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectCallAdapter~new(endpoint,'DIRECT','LOCAL'),'LOCAL')
r=selector~execute(.ConnectIntent~new('time.event.resolve','REQUEST','IMMEDIATE','AUTO','LOCAL'),a)
if \r~ok | r~value['authoritySequence'] \= 3 | r~value['occurrences'][1]['local'] \= '2026-10-26T12:15:00' then do; say 'FAIL historic DIRECT'; exit 1; end
a~remove('asOfRevision')
r=selector~execute(.ConnectIntent~new('time.event.resolve','REQUEST','IMMEDIATE','AUTO','LOCAL'),a)
if \r~ok | r~value['authoritySequence'] \= 4 | r~value['occurrences'][1]['local'] \= '2026-10-26T13:00:00' then do; say 'FAIL live DIRECT'; exit 1; end
info=selector~execute(.ConnectIntent~new('time.authority.info','REQUEST','IMMEDIATE','AUTO','LOCAL'),.directory~new)
if \info~ok | info~value['revision'] \= 4 then do; say 'FAIL authority metadata DIRECT'; exit 1; end
reg=.RpcServiceRegistry~new
endpoint~publishTo(reg)
reg~freeze
info2=.RpcServiceDispatcher~new(reg)~invoke('time','authority.info',.directory~new)
if \info2~ok | info2~value['revision'] \= 4 then do; say 'FAIL RPC Core registration'; exit 1; end
/* A durable queue operation is never implied by journal persistence. */
q=selector~execute(.ConnectIntent~new('time.event.resolve','ENQUEUE','DURABLE','AUTO','LOCAL'),a)
if q~ok then do; say 'FAIL fabricated queue dispatch'; exit 1; end
handler=.TimeJsonRpcHandler~new(endpoint)
methods=.JsonRpcMethodRegistry~new
methods~register('time.event.resolve',handler)
methods~register('time.authority.info',handler)
client=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(methods)))
policy2=.ConnectRoutePolicy~new
policy2~allow('time.event.resolve','REQUEST','RPC','LOOPBACK')
policy2~allow('time.authority.info','REQUEST','RPC','LOOPBACK')
sel2=.ConnectSelector~new(policy2)
sel2~register('RPC',.ConnectCallAdapter~new(client,'RPC','LOOPBACK'),'LOOPBACK')
a=.directory~new
a['institution']=.JsonString~new('SCHOOL')
a['phrase']=.JsonString~new('dinner')
a['onDate']=.JsonString~new('2026-10-26')
a['asOfRevision']=3
j=sel2~execute(.ConnectIntent~new('time.event.resolve','REQUEST','IMMEDIATE','AUTO','LOOPBACK'),a)
if \j~ok then do; say 'FAIL JSON-RPC historical' j~code j~detail; exit 1; end
if j~value['authoritySequence']~isA(.JsonString) | j~value['authoritySequence'] \= 3 then do; say 'FAIL numeric historical revision'; exit 1; end
if \j~value['eventId']~isA(.JsonString) | j~value['eventId'] \= '007' | \j~value['authorityHeadChecksum']~isA(.JsonString) then do; say 'FAIL string ID projection'; exit 1; end
if j~value['occurrences'][1]['local'] \= '2026-10-26T12:15:00' then do; say 'FAIL JSON-RPC prior state'; exit 1; end
j=sel2~execute(.ConnectIntent~new('time.authority.info','REQUEST','IMMEDIATE','AUTO','LOOPBACK'),.directory~new)
if \j~ok | j~value['revision']~isA(.JsonString) | j~value['revision'] \= 4 then do; say 'FAIL JSON-RPC authority metadata'; exit 1; end
if \j~value['headChecksum']~isA(.JsonString) then do; say 'FAIL checksum represented as non-string'; exit 1; end
unused=SysFileDelete(path)
say 'PASS: ConnectSelector DIRECT + RPC Core + JSON-RPC historical authority, no queue dispatch'
::requires 'TzifZoneProvider.cls'
::requires 'TimeServiceEndpoint.cls'
::requires 'TimeJsonRpcBinding.cls'
::requires 'ConnectSelector.cls'
::requires 'RpcServiceCore.cls'
