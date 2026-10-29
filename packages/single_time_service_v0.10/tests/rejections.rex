/* Bad input must fail closed, not pick a random zone/time or guess offset. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
if \mustReject(p,'../Europe/London') then do; say 'FAIL traversal'; exit 1; end
if \mustReject(p,'Europe//London') then do; say 'FAIL double slash'; exit 1; end
if \mustReject(p,'America/NoSuchZone') then do; say 'FAIL unknown zone'; exit 1; end
if \mustRejectIso('1900-02-29T12:00:00') then do; say 'FAIL nonexistent leap day'; exit 1; end
if \mustRejectIso('2026-10-31T24:00:00') then do; say 'FAIL hour range'; exit 1; end
if \mustRejectIso('2026-10-31 12:00:00') then do; say 'FAIL loose ISO parsing'; exit 1; end
s=.SingleTimeService~new
s~registerZone(p~load('Europe/London'))
if \mustRejectFuture(s) then do; say 'FAIL unexpanded future TZ tail'; exit 1; end
say 'PASS: malformed ISO, traversal, unknown zone, bounded future'
::routine mustReject
  use strict arg provider, zone
  signal on syntax name rejected
  ignore=provider~load(zone)
  return .false
rejected:
  return .true
::routine mustRejectIso
  use strict arg iso
  signal on syntax name rejected
  ignore=.IsoCivilClock~parseLocal(iso)
  return .false
rejected:
  return .true
::routine mustRejectFuture
  use strict arg service
  signal on syntax name rejected
  ignore=service~offsetAt('Europe/London',.TimeInstant~new(2208988800))
  return .false
rejected:
  return .true
::requires 'TzifZoneProvider.cls'
