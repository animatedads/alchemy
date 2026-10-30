/* Durable revisions, restart, history, rejected mutation, and explicit context. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
path='tests/.time_authority_v06_probe.journal'
ignored=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
if l~revision \= 0 then do; say 'FAIL empty'; exit 1; end
seq=l~addCalendar('SCHOOL','Europe/London','term-v1',0)
seq=l~addEvent('meal-007','SCHOOL','School dinner','MEAL','2026-10-01','2026-12-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-v1',seq)
seq=l~bindPhrase('SCHOOL','dinner','meal-007',seq)
a=l~resolveCurrent('SCHOOL','dinner','2026-10-26',s)
if a['status'] \= 'RESOLVED' | a['occurrences'][1]['local'] \= '2026-10-26T12:15:00' then do; say 'FAIL first' a['status']; exit 1; end
seq=l~moveDate('meal-007','2026-10-26','13:00:00','Timetable amendment',seq)
new=l~resolveCurrent('SCHOOL','dinner','2026-10-26',s)
old=l~resolveAt('SCHOOL','dinner','2026-10-26',s,3)
if new['occurrences'][1]['local'] \= '2026-10-26T13:00:00' | old['occurrences'][1]['local'] \= '2026-10-26T12:15:00' | new['authorityHeadChecksum'] == old['authorityHeadChecksum'] then do; say 'FAIL history'; exit 1; end
fresh=.TimeAuthorityLedger~new(path)
if fresh~revision \= 4 | fresh~headChecksum \== l~headChecksum then do; say 'FAIL restart'; exit 1; end
again=fresh~resolveCurrent('SCHOOL','dinner','2026-10-26',s)
if again['occurrences'][1]['local'] \= '2026-10-26T13:00:00' then do; say 'FAIL replay'; exit 1; end
if \stale(fresh) then do; say 'FAIL stale write permitted'; exit 1; end
if fresh~revision \= 4 then do; say 'FAIL stale mutation'; exit 1; end
seq=fresh~closeDate('SCHOOL','2026-10-26','Institute closed',4)
closed=fresh~resolveCurrent('SCHOOL','dinner','2026-10-26',s)
if closed['status'] \= 'CLOSED' then do; say 'FAIL closure'; exit 1; end
before=fresh~resolveAt('SCHOOL','dinner','2026-10-26',s,4)
if before['status'] \= 'RESOLVED' then do; say 'FAIL historic reopen'; exit 1; end
seq=fresh~unbindPhrase('SCHOOL','dinner','meal-007',seq)
missing=fresh~resolveCurrent('SCHOOL','dinner','2026-10-26',s)
if missing['status'] \= 'UNKNOWN_EXPRESSION' then do; say 'FAIL revoke'; exit 1; end
if fresh~resolveAt('SCHOOL','dinner','2026-10-26',s,4)['status'] \= 'RESOLVED' then do; say 'FAIL retrospective revoke'; exit 1; end
ignored=SysFileDelete(path)
say 'PASS: persistent authority recovery, historical resolve, closure, revocation, concurrency guard'
exit 0
stale:
  use strict arg ledger
  signal on syntax name rejected
  seq=ledger~closeDate('SCHOOL','2026-10-27','Invalid stale',2)
  return .false
rejected:
  return .true
::requires 'TzifZoneProvider.cls'
::requires 'TimeAuthorityLedger.cls'
