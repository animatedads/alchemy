/* Concrete ConnectSelector dev2 + RPC Core dev1 registration. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
c=.TimeEventCatalog~new
cal=.TimeInstitutionCalendar~new('SCH','Europe/London','term-r4')
c~registerCalendar(cal)
event=.TimeNamedEvent~new('007','SCH','School dinner','MEAL','2026-10-01','2026-12-31','12:15:00')
c~registerEvent(event)~bindPhrase('SCH','dinner','007')
endpoint=.TimeServiceEndpoint~new(s,c)
policy=.ConnectRoutePolicy~new
policy~allow('time.event.resolve','REQUEST','DIRECT','LOCAL')
selector=.ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectCallAdapter~new(endpoint,'DIRECT','LOCAL'),'LOCAL')
a=.directory~new
a['institution']='SCH'; a['phrase']='Dinner'; a['onDate']='2026-10-26'
r=selector~execute(.ConnectIntent~new('time.event.resolve','REQUEST','IMMEDIATE','AUTO','LOCAL'),a)
if \r~ok | r~value['status'] \= 'RESOLVED' | r~value['eventId'] \= '007' then do; say 'FAIL DIRECT event resolution'; exit 1; end
if r~value['elapsedDurationSeconds'] \= 1800 | r~value['occurrences']~items \= 1 then do; say 'FAIL event duration/occurrence'; exit 1; end
reg=.RpcServiceRegistry~new
endpoint~publishTo(reg)
reg~freeze
reply=.RpcServiceDispatcher~new(reg)~invoke('time','event.resolve',a)
if \reply~ok | reply~value['status'] \= 'RESOLVED' then do; say 'FAIL RPC Core event registration'; exit 1; end
noDate=.directory~new
noDate['institution']='SCH'; noDate['phrase']='dinner'
r=selector~execute(.ConnectIntent~new('time.event.resolve','REQUEST','IMMEDIATE','AUTO','LOCAL'),noDate)
if r~ok | r~code \= 'CALL_FAILED' then do; say 'FAIL no implicit TODAY'; exit 1; end
r=selector~execute(.ConnectIntent~new('time.event.resolve','ENQUEUE','DURABLE','AUTO','LOCAL'),a)
if r~ok | r~code \= 'NO_ELIGIBLE_PROVIDER' then do; say 'FAIL no default enqueue'; exit 1; end
say 'PASS: event lookup via ConnectSelector DIRECT and RPC Core, no implied queue/schedule'
::requires 'TzifZoneProvider.cls'
::requires 'TimeServiceEndpoint.cls'
::requires 'ConnectSelector.cls'
::requires 'RpcServiceCore.cls'
