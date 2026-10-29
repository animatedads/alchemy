/* DST validation around UK 2026 change dates. Explicit synthetic coverage. */
numeric digits 20
z = .TimeZoneRules~new('Europe/London')
z~addPeriod(0,0,'GMT')
z~addPeriod(1774746000,3600,'BST')
z~addPeriod(1792890000,0,'GMT')
s = .SingleTimeService~new
s~registerZone(z)
/* 2026-03-29 01:30 local is nonexistent; 02:30 is unique.
   2026-10-25 01:30 local occurs twice. */
failures = 0
r = s~resolveLocal('Europe/London',.TimeLocalReading~new(1774747800))
if r~status \= 'GAP' then do; say 'FAIL spring gap:' r~status; failures += 1; end
r = s~resolveLocal('Europe/London',.TimeLocalReading~new(1792891800))
if r~status \= 'FOLD' then do; say 'FAIL autumn fold:' r~status; failures += 1; end
if r~candidates~items = 2 then do
 if r~choose('EARLIER')~ticks \= 1792888200 then do; say 'FAIL earlier'; failures += 1; end
 if r~choose('LATER')~ticks \= 1792891800 then do; say 'FAIL later'; failures += 1; end
end
r = s~resolveLocal('Europe/London',.TimeLocalReading~new(1792900000))
if r~status \= 'UNIQUE' then do; say 'FAIL unique:' r~status; failures += 1; end
changes = s~transitionsBetween('Europe/London',.TimeInstant~new(1770000000),.TimeInstant~new(1800000000))
if changes~items \= 2 then do; say 'FAIL transition count'; failures += 1; end
/* Artificial 30-minute shift: validates the engine does not assume 3600. */
h = .TimeZoneRules~new('Test/HalfHour')
h~addPeriod(0,36000,'BASE')
h~addPeriod(100000,37800,'PLUS30')
h~addPeriod(200000,36000,'BASE')
s~registerZone(h)
r = s~resolveLocal('Test/HalfHour',.TimeLocalReading~new(136500))
if r~status \= 'GAP' then do; say 'FAIL half-hour gap:' r~status; failures += 1; end
r = s~resolveLocal('Test/HalfHour',.TimeLocalReading~new(236500))
if r~status \= 'FOLD' then do; say 'FAIL half-hour fold:' r~status; failures += 1; end
if failures > 0 then exit 1
say 'PASS: gap, fold, earlier/later, unique, transitions, 30-minute changes'
exit 0
::requires 'SingleTime.cls'
