/* Trusted, pre-published TZif snapshots: one authority revision, two TZDBs.
 * The fixed-offset London snapshot is synthetic and NOT actual UK history. */
numeric digits 30
catalog=.TimeRuleSnapshotCatalog~new('snapshots')
info=catalog~inspect('fixture-2025b')
if info['edition'] \= '2025b' | info['zoneOrder']~items \= 4 then call fail 'snapshot manifest inspection'
prior=catalog~loadService('fixture-2025b',.array~of('Europe/London','Australia/Sydney'))
changed=catalog~loadService('synthetic-uk-fixed',.array~of('Europe/London'))
m1=prior~zoneMetadata('Europe/London')
m2=changed~zoneMetadata('Europe/London')
if m1['edition'] == m2['edition'] then call fail 'edition identity must be pinned'
if prior~differenceAt('Europe/London','Australia/Sydney',.TimeInstant~new(1791457200)) \= 36000 then call fail 'archived 2026 Sydney difference'
if prior~offsetAt('Europe/London',.TimeInstant~new(1783425600)) \= 3600 then call fail 'UK July offset'
if changed~offsetAt('Europe/London',.TimeInstant~new(1783425600)) \= 0 then call fail 'synthetic fixed-offset example'
path='tests/.time_snapshot_v08.journal'
unused=SysFileDelete(path)
ledger=.TimeAuthorityLedger~new(path)
r=ledger~addCalendar('SCHOOL','Europe/London','summer-2026',0)
r=ledger~addEvent('lunch-7','SCHOOL','School dinner','MEAL','2026-07-01','2026-07-31','12:15:00', 'WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-v1',r)
r=ledger~bindPhrase('SCHOOL','dinner','lunch-7',r)
impact=.TimeImpactAnalyzer~new(ledger,prior,changed)~compare('SCHOOL','dinner','2026-07-07','2026-07-07',r,r)
if impact['changedDays'] \= 1 | impact['unchangedDays'] \= 0 then call fail 'snapshot-to-snapshot impact'
change=impact['changes'][1]
if change['utcDeltaSeconds'] \= 3600 then call fail 'synthetic UTC shift'
if \hasReason(change,'RULE_EDITION_CHANGED') | \hasReason(change,'UTC_PROJECTION_CHANGED') then call fail 'rule impact reasons'
if hasReason(change,'LOCAL_TIME_CHANGED') then call fail 'rule change cannot move wall-time intention'
call rejects 'missing-snapshot'
call rejects 'wrong-zone'
call rejects 'unsafe-path'
unused=SysFileDelete(path)
say 'PASS: pinned rule snapshots, explicit comparison, verified bytes, negative scenarios'
exit 0
fail:
  say 'FAIL:' arg(1)
  exit 1
hasReason: procedure
  use strict arg change, expected
  do reason over change['reasonCodes']
    if reason == expected then return .true
  end
  return .false
rejects: procedure expose catalog
  use strict arg what
  signal on syntax name rejected
  select
    when what=='missing-snapshot' then bad=catalog~loadService('no-snapshot',.array~of('Europe/London'))
    when what=='wrong-zone' then bad=catalog~loadService('fixture-2025b',.array~of('Pacific/Apia'))
    when what=='unsafe-path' then bad=catalog~loadService('../fixture-2025b',.array~of('Europe/London'))
  end
  say 'FAIL: unhandled rejection' what
  exit 1
rejected:
  signal off syntax
  return
::requires 'TimeRuleSnapshots.cls'
::requires 'TimeImpactAnalysis.cls'
