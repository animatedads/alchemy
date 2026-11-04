/* Native TZif v1/2/4, 64-bit transitions and malformed binary inputs. */
numeric digits 30
p=.TzifZoneProvider~new('fixtures','synthetic')
s=.SingleTimeService~new
s~registerZone(p~load('synthetic/future2040.tzif'))
if s~offsetAt('synthetic/future2040.tzif',.TimeInstant~new(2208988800)) \= 3600 then do; say 'FAIL 64-bit transition'; exit 1; end
if s~offsetAt('synthetic/future2040.tzif',.TimeInstant~new(2240524800)) \= 0 then do; say 'FAIL second 64-bit transition'; exit 1; end
if s~offsetAt('synthetic/future2040.tzif',.TimeInstant~new(2524608000)) \= 0 then do; say 'FAIL valid fixed footer'; exit 1; end
legacy=p~load('synthetic/legacy-v1.tzif')
s~registerZone(legacy)
if s~offsetAt('synthetic/legacy-v1.tzif',.TimeInstant~new(-120000000)) \= 1800 then do; say 'FAIL negative v1'; exit 1; end
if \expectFail(p,'synthetic/bad-magic.tzif') then do; say 'FAIL bad-magic'; exit 1; end
if \expectFail(p,'synthetic/bad-truncated.tzif') then do; say 'FAIL truncated'; exit 1; end
if \expectFail(p,'synthetic/right-leap-v4.tzif') then do; say 'FAIL leap second'; exit 1; end
say 'PASS: TZif v1, v2 64-bit 2040+, fixed footer, malformed, v4 leap rejection'
::routine expectFail
  use strict arg provider, id
  signal on syntax name rejected
  ignore=provider~load(id)
  return .false
rejected:
  return .true
::requires 'TzifZoneProvider.cls'
