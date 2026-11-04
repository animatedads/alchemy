/* All policies and resource bounds fail closed. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
e=.TimeRecurrenceEngine~new(s)
if \badSpec('MONTHLY',1,'','SKIP','EARLIER') then do; say 'FAIL unsupported monthly'; exit 1; end
if \badSpec('DAILY',1,'MO','SKIP','EARLIER') then do; say 'FAIL daily mask'; exit 1; end
if \badSpec('WEEKLY',1,'MO,MO','SKIP','EARLIER') then do; say 'FAIL duplicate mask'; exit 1; end
if \badSpec('WEEKLY',1,'MO,','SKIP','EARLIER') then do; say 'FAIL trailing comma'; exit 1; end
if \badSpec('DAILY',0,'','SKIP','EARLIER') then do; say 'FAIL interval=0'; exit 1; end
if \badSpec('DAILY',1,'','SHIFT','EARLIER') then do; say 'FAIL invented gap shift'; exit 1; end
if \badSpec('DAILY',1,'','SKIP','RANDOM') then do; say 'FAIL invented fold choice'; exit 1; end
spec=.TimeRecurrenceSpec~new('uk','Europe/London','2026-03-28T01:30:00','DAILY',1,'','REJECT','EARLIER')
if \mustFail(e,spec,'2026-03-28T00:00:00','2026-03-30T23:59:59') then do; say 'FAIL gap rejection'; exit 1; end
spec=.TimeRecurrenceSpec~new('uk','Europe/London','2026-10-24T01:30:00','DAILY',1,'','SKIP','REJECT')
if \mustFail(e,spec,'2026-10-24T00:00:00','2026-10-26T23:59:59') then do; say 'FAIL fold rejection'; exit 1; end
spec=.TimeRecurrenceSpec~new('uk','Europe/London','2026-10-24T01:30:00')
if \mustFail(e,spec,'2026-10-26T00:00:00','2026-10-24T00:00:00') then do; say 'FAIL reversed interval'; exit 1; end
if \mustFail(e,spec,'2026-10-24T00:00:00','2026-10-26T23:59:59',2) then do; say 'FAIL days bound'; exit 1; end
if \mustFail(e,spec,'2026-10-24T00:00:00','2026-10-26T23:59:59',366,2) then do; say 'FAIL output bound'; exit 1; end
spec=.TimeRecurrenceSpec~new('uk','Europe/London','2100-01-01T09:00:00')
if \mustFail(e,spec,'2100-01-01T00:00:00','2100-01-01T23:59:59') then do; say 'FAIL tzdb future uncertainty'; exit 1; end
spec=.TimeRecurrenceSpec~new('weekdays','Europe/London','2026-10-23T09:00:00','WEEKLY',1,'MO,TU,WE,TH,FR')
a=e~expand(spec,'2026-10-23T00:00:00','2026-10-26T23:59:59')
if a~items \= 2 then do; say 'FAIL weekday weekend exclusion'; exit 1; end
if a[1]~localIso \= '2026-10-23T09:00:00' | a[2]~localIso \= '2026-10-26T09:00:00' then do; say 'FAIL wall clock preservation'; exit 1; end
if a[1]~offsetSeconds \= 3600 | a[2]~offsetSeconds \= 0 then do; say 'FAIL UTC re-projection'; exit 1; end
say 'PASS: rejection policies, bounded work, UTC shift across DST, closed future coverage'
exit 0

badSpec:
  use strict arg frequency, interval, weekdays, gapPolicy, foldPolicy
  signal on syntax name rejected
  x=.TimeRecurrenceSpec~new('bad','Europe/London','2026-10-24T01:30:00',frequency,interval,weekdays,gapPolicy,foldPolicy)
  return .false
rejected:
  return .true
mustFail:
  use strict arg engine, spec, a, b, maxDays=366, maxRecords=2000
  signal on syntax name rejectedExpand
  projection=engine~expand(spec,a,b,maxDays,maxRecords)
  return .false
rejectedExpand:
  return .true
::requires 'TimeRecurrence.cls'
::requires 'TzifZoneProvider.cls'
