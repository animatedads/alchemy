/* Context is mandatory and must never be inferred from the expression. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
s~registerZone(p~load('Australia/Sydney'))
catalog=.TimeEventCatalog~new
school=.TimeInstitutionCalendar~new('SCHOOL-A','Europe/London','school-term-2026-04')
school~closeDate('2026-10-28','Half-term holiday')
home=.TimeInstitutionCalendar~new('HOME-A','Australia/Sydney','home-revision-2')
catalog~registerCalendar(school)~registerCalendar(home)
lunch=.TimeNamedEvent~new('supper-007','SCHOOL-A','School dinner','MEAL','2026-10-01','2026-12-31','12:15:00')
lunch~moveDate('2026-10-29','12:45:00','Special timetable')
lunch~cancelDate('2026-10-30','Dining hall closed')
dinner=.TimeNamedEvent~new('home-dinner','HOME-A','Home dinner','MEAL','2026-10-01','2026-12-31','18:30:00','DAILY',1,'',3600)
catalog~registerEvent(lunch)~registerEvent(dinner)
catalog~bindPhrase('SCHOOL-A','  Dinner  ','supper-007')
catalog~bindPhrase('SCHOOL-A','school dinner','supper-007')
catalog~bindPhrase('HOME-A','dinner','home-dinner')

r=catalog~resolve('SCHOOL-A',' dinner ','2026-10-26',s)
if r['status'] \= 'RESOLVED' | r['eventId'] \= 'supper-007' | r['occurrences']~items \= 1 then do; say 'FAIL school Monday'; exit 1; end
if r['occurrences'][1]['local'] \= '2026-10-26T12:15:00' | r['occurrences'][1]['instantPosixSeconds'] \= 1793016900 then do; say 'FAIL UTC school' r['occurrences'][1]['instantPosixSeconds']; exit 1; end
if r['calendarRevision'] \= 'school-term-2026-04/1' | r['tzdbEdition'] \= '2025b-test-snapshot' | r['eventRevision'] \= 'original/2' then do; say 'FAIL evidence'; exit 1; end
r=catalog~resolve('HOME-A','dinner','2026-10-26',s)
if r['eventId'] \= 'home-dinner' | r['occurrences'][1]['local'] \= '2026-10-26T18:30:00' then do; say 'FAIL home distinct'; exit 1; end
r=catalog~resolve('SCHOOL-A','school dinner','2026-10-28',s)
if r['status'] \= 'CLOSED' | r['reason'] \= 'Half-term holiday' | r['occurrences']~items \= 0 then do; say 'FAIL closure'; exit 1; end
r=catalog~resolve('SCHOOL-A','school dinner','2026-10-29',s)
if r['status'] \= 'RESOLVED' | r['occurrences'][1]['local'] \= '2026-10-29T12:45:00' | r['exception'] \= 'MOVE' then do; say 'FAIL override'; exit 1; end
r=catalog~resolve('SCHOOL-A','school dinner','2026-10-30',s)
if r['status'] \= 'CANCELLED' then do; say 'FAIL event cancel'; exit 1; end
r=catalog~resolve('SCHOOL-A','school dinner','2026-10-31',s)
if r['status'] \= 'NOT_SCHEDULED' then do; say 'FAIL weekend'; exit 1; end
r=catalog~resolve('SCHOOL-A','school dinner','2027-01-04',s)
if r['status'] \= 'OUT_OF_SCOPE' then do; say 'FAIL scope'; exit 1; end
r=catalog~resolve('OTHER','dinner','2026-10-26',s)
if r['status'] \= 'UNKNOWN_CONTEXT' then do; say 'FAIL unknown context'; exit 1; end
r=catalog~resolve('SCHOOL-A','supper','2026-10-26',s)
if r['status'] \= 'UNKNOWN_EXPRESSION' then do; say 'FAIL unknown expression'; exit 1; end

/* Dynamic discovery: alias withdrawal becomes visible immediately. */
catalog~bindPhrase('SCHOOL-A','lunch','supper-007')
if catalog~resolve('SCHOOL-A','lunch','2026-10-26',s)['status'] \= 'RESOLVED' then do; say 'FAIL dynamic bind'; exit 1; end
catalog~unbindPhrase('SCHOOL-A','lunch','supper-007')
if catalog~resolve('SCHOOL-A','lunch','2026-10-26',s)['status'] \= 'UNKNOWN_EXPRESSION' then do; say 'FAIL revoke'; exit 1; end
/* Multiple possible meanings remain unresolved until the caller selects. */
other=.TimeNamedEvent~new('staff-dinner','SCHOOL-A','Staff dinner','MEAL','2026-10-01','2026-12-31','13:00:00')
catalog~registerEvent(other)~bindPhrase('SCHOOL-A','dinner','staff-dinner')
r=catalog~resolve('SCHOOL-A','dinner','2026-10-26',s)
if r['status'] \= 'AMBIGUOUS' | r['meanings']~items \= 2 | r['occurrences']~items \= 0 then do; say 'FAIL ambiguity'; exit 1; end

/* Fold is not silently shifted, and both candidates are retained. */
cal=.TimeInstitutionCalendar~new('LONDON-FOLD','Europe/London','r1')
catalog~registerCalendar(cal)
fold=.TimeNamedEvent~new('fold-event','LONDON-FOLD','Night shift','SHIFT','2026-10-01','2026-12-31','01:30:00','DAILY',1,'',1800,'RECORD','BOTH')
catalog~registerEvent(fold)~bindPhrase('LONDON-FOLD','shift','fold-event')
r=catalog~resolve('LONDON-FOLD','shift','2026-10-25',s)
if r['status'] \= 'FOLD' | r['occurrences']~items \= 2 then do; say 'FAIL fold'; exit 1; end
r=catalog~resolve('LONDON-FOLD','shift','2026-10-24',s)
if r['status'] \= 'RESOLVED' | r['occurrences']~items \= 1 then do; say 'FAIL unique'; exit 1; end

say 'PASS: contextual meals, closures, exceptions, ambiguity, no inferred current date, fold evidence'
::requires 'TzifZoneProvider.cls'
::requires 'TimeEvents.cls'
