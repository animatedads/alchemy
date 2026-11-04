/* Civil recurrence must retain 01:30 UK wall-time across DST and explain gaps/folds. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
s~registerZone(p~load('Australia/Lord_Howe'))
s~registerZone(p~load('Pacific/Apia'))
e=.TimeRecurrenceEngine~new(s)

spec=.TimeRecurrenceSpec~new('uk-early','Europe/London','2026-03-28T01:30:00','DAILY',1,'','RECORD','EARLIER')
a=e~expand(spec,'2026-03-28T00:00:00','2026-03-30T23:59:59')
if a~items \= 3 then do; say 'FAIL spring count' a~items; exit 1; end
if a[1]~status \= 'UNIQUE' | a[2]~status \= 'GAP' | a[3]~status \= 'UNIQUE' then do; say 'FAIL spring statuses'; exit 1; end
if a[2]~instant \== .nil then do; say 'FAIL gap has executable instant'; exit 1; end
if a[1]~instant~ticks \= 1774661400 | a[3]~instant~ticks \= 1774830600 then do; say 'FAIL local time re-projection' a[1]~instant~ticks a[3]~instant~ticks; exit 1; end
if a[1]~asRecord['tzdbEdition'] \= '2025b-test-snapshot' then do; say 'FAIL edition'; exit 1; end

spec=.TimeRecurrenceSpec~new('uk-late','Europe/London','2026-10-24T01:30:00','DAILY',1,'','SKIP','BOTH')
a=e~expand(spec,'2026-10-24T00:00:00','2026-10-26T23:59:59')
if a~items \= 4 then do; say 'FAIL fold BOTH count' a~items; exit 1; end
if a[2]~status \= 'FOLD' | a[3]~status \= 'FOLD' then do; say 'FAIL fold statuses'; exit 1; end
if a[2]~instant~ticks \= 1792888200 | a[3]~instant~ticks \= 1792891800 then do; say 'FAIL fold instant ordering'; exit 1; end
spec=.TimeRecurrenceSpec~new('uk-late','Europe/London','2026-10-24T01:30:00','DAILY',1,'','SKIP','LATER')
a=e~expand(spec,'2026-10-24T00:00:00','2026-10-26T23:59:59')
if a~items \= 3 | a[2]~instant~ticks \= 1792891800 then do; say 'FAIL LATER selection'; exit 1; end

spec=.TimeRecurrenceSpec~new('school','Europe/London','2026-10-26T09:00:00','WEEKLY',2,'MO,TU,WE,TH,FR','SKIP','EARLIER')
a=e~expand(spec,'2026-10-26T00:00:00','2026-11-15T23:59:59')
if a~items \= 10 then do; say 'FAIL alternate fortnight weekdays' a~items; exit 1; end
if a[1]~localIso \= '2026-10-26T09:00:00' | a[6]~localIso \= '2026-11-09T09:00:00' then do; say 'FAIL week bounds'; exit 1; end

spec=.TimeRecurrenceSpec~new('lord-howe','Australia/Lord_Howe','2026-10-03T02:15:00','DAILY',1,'','RECORD','EARLIER')
a=e~expand(spec,'2026-10-03T00:00:00','2026-10-05T23:59:59')
if a~items \= 3 | a[2]~status \= 'GAP' then do; say 'FAIL half-hour rule'; exit 1; end

spec=.TimeRecurrenceSpec~new('apia','Pacific/Apia','2011-12-29T12:00:00','DAILY',1,'','RECORD','EARLIER')
a=e~expand(spec,'2011-12-29T00:00:00','2011-12-31T23:59:59')
if a~items \= 3 | a[2]~status \= 'GAP' then do; say 'FAIL date line skip'; exit 1; end

say 'PASS: daily gap, fold choices, anchored biweekly weekdays, Lord Howe, Samoa, versioned results'
::requires 'TzifZoneProvider.cls'
::requires 'TimeRecurrence.cls'
