/* Independent expected instants for non-hour, skipped day and offset variety. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
z=.array~of('Australia/Lord_Howe','Pacific/Apia','Asia/Kathmandu','Australia/Sydney','Australia/Brisbane','Pacific/Chatham')
do i=1 to z~items
  s~registerZone(p~load(z[i]))
end
r=s~resolveIsoLocal('Australia/Lord_Howe','2026-10-04T02:15:00')
if r~status \= 'GAP' then do; say 'FAIL Lord Howe spring gap' r~status; exit 1; end
r=s~resolveIsoLocal('Australia/Lord_Howe','2026-04-05T01:45:00')
if r~status \= 'FOLD' then do; say 'FAIL Lord Howe fold' r~status; exit 1; end
if r~choose('EARLIER')~ticks \= 1775313900 | r~choose('LATER')~ticks \= 1775315700 then do; say 'FAIL Lord Howe fold instants'; exit 1; end
r=s~resolveIsoLocal('Pacific/Apia','2011-12-30T12:00:00')
if r~status \= 'GAP' then do; say 'FAIL Samoa skipped date' r~status; exit 1; end
r=s~resolveIsoLocal('Asia/Kathmandu','2026-01-01T12:00:00')
if r~choose('ONLY')~ticks \= 1767248100 then do; say 'FAIL Kathmandu offset'; exit 1; end
r=s~resolveIsoLocal('Australia/Sydney','2026-10-31T12:00:00')
if r~choose('ONLY')~ticks \= 1793408400 then do; say 'FAIL Sydney offset'; exit 1; end
r=s~resolveIsoLocal('Australia/Brisbane','2026-10-31T12:00:00')
if r~choose('ONLY')~ticks \= 1793412000 then do; say 'FAIL Brisbane no DST'; exit 1; end
r=s~resolveIsoLocal('Pacific/Chatham','2026-10-31T12:00:00')
if r~choose('ONLY')~ticks \= 1793398500 then do; say 'FAIL Chatham 45-minute offset'; exit 1; end
metadata=s~zoneMetadata('Pacific/Chatham')
if metadata['edition'] \= '2025b-test-snapshot' | metadata['periodCount'] < 10 then do; say 'FAIL provenance'; exit 1; end
say 'PASS: Lord Howe gap/fold, Samoa skipped day, Kathmandu, Brisbane, Chatham, metadata'
::requires 'TzifZoneProvider.cls'
