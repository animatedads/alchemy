/* ISO conversion is independent of host TZ settings and tzdb. */
numeric digits 30
samples=.array~of('1970-01-01T00:00:00','1969-12-31T23:59:59', '2000-02-29T12:34:56', '1900-02-28T23:59:59','0001-01-01T00:00:00','9999-12-31T23:59:59','2026-10-25T01:30:00')
do i=1 to samples~items
  reading=.IsoCivilClock~parseLocal(samples[i])
  fmt=.IsoCivilClock~formatLocal(reading)
  if fmt \= samples[i] then do; say 'FAIL roundtrip:' samples[i] fmt; exit 1; end
end
if .IsoCivilClock~parseLocal('1970-01-01T00:00:00')~coordinate \= 0 then do; say 'FAIL epoch'; exit 1; end
if .IsoCivilClock~parseLocal('2000-01-01T00:00:00')~coordinate \= 946684800 then do; say 'FAIL year2000'; exit 1; end
provider=.TzifZoneProvider~new('fixtures','HOST-TZDATA-2025')
s=.SingleTimeService~new
s~registerZone(provider~load('Europe/London'))
r=s~resolveIsoLocal('Europe/London','2026-03-29T01:30:00')
if r~status \= 'GAP' then do; say 'FAIL ISO gap'; exit 1; end
r=s~resolveIsoLocal('Europe/London','2026-10-25T01:30:00')
if r~status \= 'FOLD' then do; say 'FAIL ISO fold'; exit 1; end
if r~choose('EARLIER')~ticks \= 1792888200 then do; say 'FAIL ISO earlier'; exit 1; end
if r~choose('LATER')~ticks \= 1792891800 then do; say 'FAIL ISO later'; exit 1; end
if s~isoLocalAt('Europe/London',r~choose('EARLIER')) \= '2026-10-25T01:30:00' then do; say 'FAIL ISO inverse'; exit 1; end
say 'PASS: ISO civil parse/format, epoch, Gregorian leap years, gap/fold'
::requires 'TzifZoneProvider.cls'
