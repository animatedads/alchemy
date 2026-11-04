/* Semantic faults fail closed; no invalid dates, spoofed institutional aliases
 * or unspecified time policies are accepted. */
numeric digits 30
s=.SingleTimeService~new
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s~registerZone(p~load('Europe/London'))
c=.TimeEventCatalog~new
cal=.TimeInstitutionCalendar~new('SCH','Europe/London','term')
c~registerCalendar(cal)
e=.TimeNamedEvent~new('lunch','SCH','Dinner','MEAL','2026-10-01','2026-12-31','12:00:00')
c~registerEvent(e)~bindPhrase('SCH','dinner','lunch')
if \invalidDate(c,s,'2026-02-30') then do; say 'FAIL invalid civil date'; exit 1; end
if \invalidDate(c,s,'2026-13-01') then do; say 'FAIL invalid month'; exit 1; end
if \invalidDate(c,s,'20261001') then do; say 'FAIL invalid format'; exit 1; end
if \invalidClock() then do; say 'FAIL invalid clock'; exit 1; end
other=.TimeInstitutionCalendar~new('OTHER','Europe/London','rev2')
c~registerCalendar(other)
if \crossBind(c) then do; say 'FAIL crossed institution'; exit 1; end
if \duplicateBind(c) then do; say 'FAIL duplicate alias'; exit 1; end
if \unbound(c) then do; say 'FAIL undeclared revoke'; exit 1; end
/* A calendar closure wins over an event time override, regardless of order. */
e~moveDate('2026-10-29','12:40:00','Early pickup')
cal~closeDate('2026-10-29','School closed')
r=c~resolve('SCH','dinner','2026-10-29',s)
if r['status'] \= 'CLOSED' | r['occurrences']~items \= 0 | r['calendarRevision'] \= 'term/1' then do; say 'FAIL calendar closure authority'; exit 1; end
/* A mutable definition change has a visibly different revision. */
if r['eventRevision'] \= 'original/1' then do; say 'FAIL exception revision'; exit 1; end
say 'PASS: event validation, aliases, closure precedence, evidence revisions'
exit 0
invalidDate:
  use strict arg catalog, service, date
  signal on syntax name rejected
  value=catalog~resolve('SCH','dinner',date,service)
  return .false
rejected:
  return .true
invalidClock:
  signal on syntax name rejectedClock
  e=.TimeNamedEvent~new('bad','SCH','bad','MEAL','2026-10-01','2026-12-31','25:99:00')
  return .false
rejectedClock:
  return .true
crossBind:
  use strict arg catalog
  signal on syntax name rejectedCross
  catalog~bindPhrase('OTHER','dinner','lunch')
  return .false
rejectedCross:
  return .true
duplicateBind:
  use strict arg catalog
  signal on syntax name rejectedDuplicate
  catalog~bindPhrase('SCH','dinner','lunch')
  return .false
rejectedDuplicate:
  return .true
unbound:
  use strict arg catalog
  signal on syntax name rejectedUnbound
  catalog~unbindPhrase('SCH','dinner','other')
  return .false
rejectedUnbound:
  return .true
::requires 'TzifZoneProvider.cls'
::requires 'TimeEvents.cls'
