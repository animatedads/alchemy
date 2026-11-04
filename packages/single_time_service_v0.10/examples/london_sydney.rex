/* Human-readable dated comparison with frozen tzdb fixture authority. */
numeric digits 30
s=.SingleTimeService~new
p=.TzifZoneProvider~new('fixtures','2025b-fixture')
s~registerZone(p~load('Europe/London'))~registerZone(p~load('Australia/Sydney'))
dates=.array~of('2026-10-01T12:00:00','2026-10-08T12:00:00','2026-10-31T12:00:00')
do i=1 to dates~items
  local=s~resolveIsoLocal('Europe/London',dates[i])
  report=s~explainDifferenceAt('Europe/London','Australia/Sydney',local~choose('ONLY'))
  say report['fromLocal'] report['fromAbbreviation'] '->' report['toLocal'] report['toAbbreviation']
  say '  Sydney ahead hours:' report['differenceSeconds']/3600 'TZDB:' report['fromEdition']
end
::requires 'TzifZoneProvider.cls'
