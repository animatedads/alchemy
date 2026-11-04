/* JSON-RPC loopback registration uses exact published event.resolve operation. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
c=.TimeEventCatalog~new
c~registerCalendar(.TimeInstitutionCalendar~new('SCH','Europe/London','term-r4'))
c~registerEvent(.TimeNamedEvent~new('007','SCH','School dinner','MEAL','2026-10-01','2026-12-31','12:15:00'))
c~bindPhrase('SCH','dinner','007')
endpoint=.TimeServiceEndpoint~new(s,c)
handler=.TimeJsonRpcHandler~new(endpoint)
reg=.JsonRpcMethodRegistry~new
reg~register('time.event.resolve',handler)
transport=.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(reg))
client=.JsonRpcClient~new(transport)
policy=.ConnectRoutePolicy~new
policy~allow('time.event.resolve','REQUEST','RPC','LOOPBACK')
sel=.ConnectSelector~new(policy)
sel~register('RPC',.ConnectCallAdapter~new(client,'RPC','LOOPBACK'),'LOOPBACK')
a=.directory~new
a['institution']=.JsonString~new('SCH')
a['phrase']=.JsonString~new('dinner')
a['onDate']=.JsonString~new('2026-10-26')
r=sel~execute(.ConnectIntent~new('time.event.resolve','REQUEST','IMMEDIATE','AUTO','LOOPBACK'),a)
if \r~ok then do; say 'FAIL JSON-RPC event' r~code r~detail; exit 1; end
if r~value['status'] \= 'RESOLVED' | r~value['eventId'] \= '007' then do; say 'FAIL JSON-RPC event identity'; exit 1; end
if \r~value['eventId']~isA(.JsonString) then do; say 'FAIL numeric-looking ID changed type'; exit 1; end
if r~value['elapsedDurationSeconds']~isA(.JsonString) | r~value['elapsedDurationSeconds'] \= 1800 then do; say 'FAIL numeric elapsed duration'; exit 1; end
if r~value['catalogRevision']~isA(.JsonString) | r~value['catalogRevision'] \= 3 then do; say 'FAIL numeric catalog revision'; exit 1; end
if r~value['occurrences'][1]['instantPosixSeconds']~isA(.JsonString) then do; say 'FAIL numeric POSIX instant'; exit 1; end
say 'PASS: ConnectSelector JSON-RPC event resolution and typed wire values'
::requires 'TzifZoneProvider.cls'
::requires 'TimeServiceEndpoint.cls'
::requires 'TimeJsonRpcBinding.cls'
::requires 'ConnectSelector.cls'
