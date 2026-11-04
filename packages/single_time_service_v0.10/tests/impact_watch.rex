/* Local pull watch requires explicit acknowledged checkpoint; never pushes. */
numeric digits 30
s=.SingleTimeService~new
s~registerZone(.TzifZoneProvider~new('fixtures','2025b-test-snapshot')~load('Europe/London'))
path='tests/.time_impact_watch.journal'
unused=SysFileDelete(path)
l=.TimeAuthorityLedger~new(path)
r=l~addCalendar('SCHOOL','Europe/London','term',0)
r=l~addEvent('007','SCHOOL','Dinner','MEAL','2026-10-01','2026-12-31','12:15:00','WEEKLY',1,'MO,TU,WE,TH,FR',1800,'RECORD','EARLIER','e1',r)
r=l~bindPhrase('SCHOOL','dinner','007',r)
a=.TimeImpactAnalyzer~new(l,s)
w=.TimeChangeWatch~new(l,a,'schoolwatch','SCHOOL','dinner','2026-10-26','2026-10-28',r)
if w~poll['status'] \= 'NO_NEW_REVISION' then call fail 'no new revision'
first=w~checkpoint
if first['revision'] \= 3 | first['headChecksum'] == '' then call fail 'checkpoint'
r=l~moveDate('007','2026-10-26','13:00:00','Changed',r)
offer=w~poll
if offer['status'] \= 'IMPACT' | offer['impact']['changedDays'] \= 1 then call fail 'impact offer'
if w~cursorRevision \= 3 then call fail 'implicit acknowledgement'
again=w~poll
if again['impact']['changes'][1]['utcDeltaSeconds'] \= 2700 then call fail 'at least once replay'
call rejected 'wrong_ack'
cp=w~acknowledge(offer['toRevision'],offer['impact']['toHeadChecksum'])
if cp['revision'] \= 4 | w~poll['status'] \= 'NO_NEW_REVISION' then call fail 'ack success'
r=l~closeDate('SCHOOL','2026-11-05','Holiday',r)
offer=w~poll
if offer['status'] \= 'NO_EFFECT' | offer['impact']['changedDays'] \= 0 then call fail 'irrelevant change'
cp=w~acknowledge(offer['toRevision'],offer['impact']['toHeadChecksum'])
w2=.TimeChangeWatch~new(l,a,'schoolwatch','SCHOOL','dinner','2026-10-26','2026-10-28',cp['revision'],cp['headChecksum'])
if w2~poll['status'] \= 'NO_NEW_REVISION' then call fail 'restored checkpoint'
call rejected 'bad_checkpoint'
unused=SysFileDelete(path)
say 'PASS: explicit poll/ack, at-least-once advisory replay, no-effect revision, externally checkpointed cursor'
exit 0
fail:
  say 'FAIL:' arg(1)
  exit 1
rejected: procedure expose w offer l a cp
  use strict arg case
  signal on syntax name expected
  select
    when case == 'wrong_ack' then cp=w~acknowledge(4,'INVALID')
    when case == 'bad_checkpoint' then bad=.TimeChangeWatch~new(l,a,'schoolwatch','SCHOOL','dinner','2026-10-26','2026-10-28',cp['revision'],'TAMPERED')
  end
  say 'FAIL: rejection missing' case
  exit 1
expected:
  signal off syntax
  return
::requires 'TzifZoneProvider.cls'
::requires 'TimeImpactAnalysis.cls'
