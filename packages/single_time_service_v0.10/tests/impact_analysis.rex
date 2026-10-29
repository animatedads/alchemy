/* Distinguish historical definition changes, local shifts and UTC changes. */
numeric digits 30
provider=.TzifZoneProvider~new('fixtures','2025b-test-snapshot')
s=.SingleTimeService~new
s~registerZone(provider~load('Europe/London'))
path='tests/.time_impact_v07.journal'
unused=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
r=l~addCalendar('SCHOOL','Europe/London','term-v1',0)
r=l~addEvent('007','SCHOOL','Dinner','MEAL','2026-10-01','2026-12-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','event-v1',r)
r=l~bindPhrase('SCHOOL','dinner','007',r)
r=l~moveDate('007','2026-10-26','13:00:00','Later lunch',r)
r=l~closeDate('SCHOOL','2026-10-27','Staff day',r)
a=.TimeImpactAnalyzer~new(l,s)
x=a~compare('SCHOOL','dinner','2026-10-26','2026-10-28',3,4)
if x['scannedDays'] \= 3 | x['changedDays'] \= 1 | x['unchangedDays'] \= 2 then call fail 'bounded comparison counts'
c=x['changes'][1]
if c['date'] \= '2026-10-26' | c['before']['occurrences'][1]['local'] \= '2026-10-26T12:15:00' then call fail 'prior local snapshot'
if c['after']['occurrences'][1]['local'] \= '2026-10-26T13:00:00' | c['utcDeltaSeconds'] \= 2700 then call fail 'moved local and instant'
if \hasReason(c,'LOCAL_TIME_CHANGED') | \hasReason(c,'UTC_PROJECTION_CHANGED') then call fail 'local and utc reason codes'
if x['fromHeadChecksum'] == x['toHeadChecksum'] then call fail 'different revision witnesses'
y=a~compare('SCHOOL','dinner','2026-10-26','2026-10-28',3,5)
if y['changedDays'] \= 2 | y['changes'][2]['date'] \= '2026-10-27' then call fail 'closure isolated'
if y['changes'][2]['after']['status'] \= 'CLOSED' | \hasReason(y['changes'][2],'STATUS_CHANGED') then call fail 'closure status'
if y['changes'][2]['utcDeltaSeconds'] \== .nil then call fail 'closure cannot have UTC delta'
r=l~cancelDate('007','2026-10-29','Special cancellation',r)
z=a~compare('SCHOOL','dinner','2026-10-29','2026-10-29',5,6)
if z['changedDays'] \= 1 | z['changes'][1]['after']['status'] \= 'CANCELLED' then call fail 'cancellation'
r=l~unbindPhrase('SCHOOL','dinner','007',r)
z=a~compare('SCHOOL','dinner','2026-10-26','2026-10-26',6,7)
if z['changedDays'] \= 1 | z['changes'][1]['after']['status'] \= 'UNKNOWN_EXPRESSION' then call fail 'unbind impact'
if \hasReason(z['changes'][1],'MEANING_CHANGED') then call fail 'meaning change'
/* The same committed institution semantics may be projected under two
 * explicitly injected timezone authorities; a revision change is unnecessary. */
newSvc=.SingleTimeService~new
newZone=.TimeZoneRules~new('Europe/London')
newZone~addPeriod(-2208988800,7200,'SYN')
newZone~setAuthority('synthetic-rules-v2','INJECTED','',.nil)
newSvc~registerZone(newZone)
b=.TimeImpactAnalyzer~new(l,s,newSvc)
z=b~compare('SCHOOL','dinner','2026-10-26','2026-10-26',3,3)
if z['ruleComparisonMode'] \= 'EXPLICIT_SNAPSHOTS' | z['changedDays'] \= 1 then call fail 'tzdb snapshots comparison'
if \hasReason(z['changes'][1],'RULE_EDITION_CHANGED') | \hasReason(z['changes'][1],'UTC_PROJECTION_CHANGED') then call fail 'rule effects'
if hasReason(z['changes'][1],'LOCAL_TIME_CHANGED') | z['changes'][1]['utcDeltaSeconds'] \= -7200 then call fail 'unchanged intention offset change'
/* Replay after restart proves no analyzer mutation and retained provenance. */
l2=.TimeAuthorityLedger~new(path)
z=.TimeImpactAnalyzer~new(l2,s)~compare('SCHOOL','dinner','2026-10-26','2026-10-26',3,4)
if z['changes'][1]['utcDeltaSeconds'] \= 2700 | l2~revision \= 7 then call fail 'journal restart immutable history'
/* Unbounded work, missing revisions and malformed dates must fail closed. */
call rejects 'bad_rev'
call rejects 'wide'
call rejects 'reversed'
call rejects 'bad_date'
unused=SysFileDelete(path)
say 'PASS: impact analysis, moves, closures, cancellations, withdrawn meanings, rule snapshots, replay and bounds'
exit 0
fail:
  say 'FAIL:' arg(1)
  exit 1
hasReason: procedure
  use strict arg item, sought
  do reason over item['reasonCodes']
    if reason == sought then return .true
  end
  return .false
rejects: procedure expose a
  use strict arg scenario
  signal on syntax name expected
  select
    when scenario == 'bad_rev' then x=a~compare('SCHOOL','dinner','2026-10-26','2026-10-26',3,90)
    when scenario == 'wide' then x=a~compare('SCHOOL','dinner','2026-01-01','2026-12-31',3,4,31)
    when scenario == 'reversed' then x=a~compare('SCHOOL','dinner','2026-10-29','2026-10-26',3,4)
    when scenario == 'bad_date' then x=a~compare('SCHOOL','dinner','2026-02-30','2026-02-30',3,4)
  end
  say 'FAIL: unhandled rejection' scenario
  exit 1
expected:
  signal off syntax
  return
::requires 'TzifZoneProvider.cls'
::requires 'TimeImpactAnalysis.cls'
